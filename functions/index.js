const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

const db = admin.firestore();

const NEWS_API_KEY = defineSecret("NEWS_API_KEY");
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

const NEWS_TOPIC = "job_news";

const CATEGORY_KEYWORDS = {
  "就活": [
    "採用",
    "就活",
    "新卒",
    "インターン",
    "面接",
    "ES",
    "内定",
    "説明会",
    "ガクチカ",
    "自己PR",
    "WEBテスト",
    "SPI",
    "エントリー",
    "選考",
    "企業研究",
  ],
  "コンサル": [
    "コンサル",
    "コンサルティング",
    "戦略コンサル",
    "アクセンチュア",
    "デロイト",
    "PwC",
    "KPMG",
    "EY",
  ],
  "メーカー": [
    "メーカー",
    "製造",
    "半導体",
    "自動車",
    "電機",
    "機械",
    "素材",
    "化学",
  ],
  "金融": [
    "銀行",
    "証券",
    "保険",
    "金融",
    "資産運用",
    "フィンテック",
  ],
  "商社": [
    "商社",
    "総合商社",
    "専門商社",
    "三菱商事",
    "伊藤忠",
    "丸紅",
    "住友商事",
  ],
  "人材 ・ 教育": [
    "人材業界",
    "教育業界",
    "研修",
    "リスキリング",
  ],
  "インフラ ・ 交通": [
    "鉄道",
    "航空",
    "物流",
    "電力",
    "ガス",
    "インフラ",
    "交通",
  ],
  "不動産 ・ 建設": [
    "不動産",
    "建設",
    "住宅",
    "デベロッパー",
    "ゼネコン",
  ],
  "旅行 ・ 観光": [
    "旅行",
    "観光",
    "ホテル",
    "航空券",
    "宿泊",
  ],
  "医療 ・ 福祉": [
    "医療",
    "福祉",
    "介護",
    "病院",
    "ヘルスケア",
    "製薬",
  ],
  "官公庁 ・ 自治体": [
    "官公庁",
    "自治体",
    "行政",
    "政府",
    "省庁",
    "地方公共団体",
  ],
  "小売 ・ 流通": [
    "小売",
    "流通",
    "EC",
    "スーパー",
    "百貨店",
    "コンビニ",
  ],
  "IT ・ 通信": [
    "IT",
    "DX",
    "AI",
    "生成AI",
    "クラウド",
    "SaaS",
    "通信業界",
    "システム",
    "エンジニア",
    "セキュリティ",
    "ソフトウェア",
  ],
  "広告 ・ 出版": [
    "広告業界",
    "出版社",
    "メディア",
    "テレビ業界",
    "マーケティング",
  ],
};

const VALID_CATEGORIES = [
  "就活",
  "コンサル",
  "IT ・ 通信",
  "メーカー",
  "金融",
  "商社",
  "広告 ・ 出版",
  "人材 ・ 教育",
  "インフラ ・ 交通",
  "不動産 ・ 建設",
  "旅行 ・ 観光",
  "医療 ・ 福祉",
  "官公庁 ・ 自治体",
  "小売 ・ 流通",
  "その他",
];

const EXCLUDE_KEYWORDS = [
  "漫画",
  "コミック",
  "マンガ",
  "アニメ",
  "子育て",
  "育児",
  "性教育",
  "恋愛",
  "芸能",
  "タレント",
  "アイドル",
  "声優",
  "スポーツ",
];

function buildSearchQuery() {
  return " (就活 OR 新卒 OR 就職活動　OR 業界動向 OR インターン) AND (人気 OR 大学生 OR アンケート OR 採用 OR インターン OR 面接 OR ES OR 内定 OR 説明会 OR SPI OR 年収 OR 初任給 OR 採用人数 OR ランキング OR IT業界 OR DX人材 OR 生成AI OR SaaS OR 通信業界 OR コンサル OR 戦略コンサル OR メーカー業界 OR 半導体 OR 自動車業界 OR 金融業界 OR 銀行 OR 証券 OR 商社 OR 広告業界 OR 出版社 OR 人材業界 OR 教育業界 OR インフラ業界 OR 鉄道業界 OR 不動産業界 OR 建設業界 OR 旅行業界 OR 観光業界 OR 医療業界 OR 福祉業界 OR 官公庁 OR 自治体 OR 小売業界 OR 流通業界)";
}

function getArticleText(article) {
  return [
    article.title || "",
    article.description || "",
    article.content || "",
    article.source?.name || "",
  ].join(" ");
}

function isRelevantArticle(article) {
  const text = getArticleText(article).toLowerCase();
  const allKeywords = Object.values(CATEGORY_KEYWORDS).flat();

  return allKeywords.some((keyword) =>
    text.includes(keyword.toLowerCase())
  );
}

function hasExcludedKeyword(article) {
  const text = getArticleText(article);
  return EXCLUDE_KEYWORDS.some((keyword) => text.includes(keyword));
}

function classifyCategoryByKeyword(article) {
  const text = getArticleText(article).toLowerCase();

  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    const matched = keywords.some((keyword) =>
      text.includes(keyword.toLowerCase())
    );

    if (matched) return category;
  }

  return "その他";
}

function safeString(value, fallback = "") {
  if (value === undefined || value === null) return fallback;
  return String(value);
}

function normalizeAiResult(result, article) {
  const keywordCategory = classifyCategoryByKeyword(article);

  const isUseful = Boolean(result?.isUseful);

  const scoreNumber = Number(result?.score);
  const score = Number.isFinite(scoreNumber)
    ? Math.max(0, Math.min(100, scoreNumber))
    : 0;

  const category = VALID_CATEGORIES.includes(result?.category)
    ? result.category
    : keywordCategory;

  const summary = safeString(
    result?.summary,
    article.description || "概要はありません"
  ).trim();

  return {
    isUseful,
    score,
    category,
    summary: summary || article.description || "概要はありません",
  };
}

async function analyzeArticle(article) {
  const apiKey = OPENAI_API_KEY.value();

  const title = article.title || "";
  const description = article.description || "";
  const source = article.source?.name || "";

  const prompt = `
あなたは日本の就活ニュース編集者です。

以下の記事について、就活アプリに掲載すべきか判定してください。

目的:
- 日本の大学生・大学院生の就職活動に役立つ記事だけを残す
- 不要なニュースを除外する
- 業界カテゴリを正確に分類する
- アプリ上で読みやすい3行要約を作る

掲載してよい記事:
- 新卒採用
- 就活
- インターン
- ES
- 面接
- 初任給
- 採用人数
- 業界研究に役立つ企業動向
- 業界研究に役立つ業界動向
- AI/DX/半導体/金融/商社/メーカー/コンサルなど、就活生の企業研究に役立つ内容
- 人材不足、リスキリング、働き方、賃上げなど就活に関係する内容

除外すべき記事:
- 芸能
- スポーツ
- 漫画
- アニメ
- 恋愛
- 子育て
- 事件事故
- 政治批判だけの記事
- 投資家向けで就活生の企業研究にほぼ役立たない記事
- 内容が薄いPR記事
- 日本の就活生に関係が薄い海外ニュース

カテゴリ候補:
${VALID_CATEGORIES.map((c) => `- ${c}`).join("\n")}

必ず次のJSONのみを返してください。
説明文やコードブロックは不要です。

{
  "isUseful": true,
  "score": 85,
  "category": "IT ・ 通信",
  "summary": "1行目\\n2行目\\n3行目"
}

scoreの基準:
- 90〜100: 就活生にかなり有益
- 75〜89: 掲載してよい
- 60〜74: 微妙
- 0〜59: 除外

記事:
タイトル: ${title}
説明: ${description}
媒体: ${source}
`;

  try {
    const response = await axios.post(
      "https://api.openai.com/v1/chat/completions",
      {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content:
              "あなたは就活生向けニュースアプリの編集者です。必ず有効なJSONのみを返してください。",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        response_format: {
          type: "json_object",
        },
        temperature: 0.2,
      },
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        timeout: 30000,
      }
    );

    const content = response.data?.choices?.[0]?.message?.content || "{}";
    const parsed = JSON.parse(content);

    return normalizeAiResult(parsed, article);
  } catch (error) {
    console.error(
      "OpenAI analyzeArticle error:",
      error.response?.data || error.message
    );

    return {
      isUseful: false,
      score: 0,
      category: classifyCategoryByKeyword(article),
      summary: article.description || "概要はありません",
    };
  }
}

function createDocId(url) {
  return Buffer.from(url)
    .toString("base64")
    .replace(/\//g, "_")
    .replace(/\+/g, "-")
    .replace(/=/g, "");
}

async function sendJobNewsNotification(savedCount) {
  if (!savedCount || savedCount <= 0) return;

  const message = {
    topic: NEWS_TOPIC,
    notification: {
      title: "就活ニュース",
      body: `就活ニュースが${savedCount}件更新されました`,
    },
    data: {
      type: "job_news",
      count: String(savedCount),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "job_news",
        sound: "default",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  const response = await admin.messaging().send(message);
  console.log(`FCM notification sent: ${response}`);
}

async function fetchAndSaveNews() {
  const apiKey = NEWS_API_KEY.value();
  const query = buildSearchQuery();

  const response = await axios.get("https://newsapi.org/v2/everything", {
    params: {
      q: query,
      sortBy: "publishedAt",
      pageSize: 100,
      domains:
        "onecareer.jp,unistyleinc.com,gaishishukatsu.com,careerpark.jp,mynavi.jp,job.rikunabi.com,itmedia.co.jp,nikkei.com,toyokeizai.net,logmi.jp,bizreach.jp,type.jp,prtimes.jp,businessinsider.jp,newspicks.com,news.yahoo.co.jp,diamond.jp",
      apiKey,
    },
  });

  const articles = response.data.articles || [];
  const batch = db.batch();

  let fetchedCount = articles.length;
  let savedCount = 0;
  let skippedCount = 0;

  for (const article of articles) {
    if (!article.title || !article.url) {
      skippedCount++;
      continue;
    }

    if (!isRelevantArticle(article)) {
      skippedCount++;
      continue;
    }

    if (hasExcludedKeyword(article)) {
      skippedCount++;
      continue;
    }

    const aiResult = await analyzeArticle(article);

    if (!aiResult.isUseful || aiResult.score < 75) {
      skippedCount++;
      continue;
    }

    const docId = createDocId(article.url);
    const ref = db.collection("news").doc(docId);

    const existingDoc = await ref.get();

    if (existingDoc.exists) {
      skippedCount++;
      continue;
    }

    const publishedDate = article.publishedAt
      ? new Date(article.publishedAt)
      : new Date();

    batch.set(
      ref,
      {
        title: article.title,
        description: article.description || "",
        summary: aiResult.summary,
        content: article.content || "",
        url: article.url,
        imageUrl: article.urlToImage || "",
        source: article.source?.name || "",
        publishedAt: admin.firestore.Timestamp.fromDate(publishedDate),
        category: aiResult.category,
        score: aiResult.score,
        isUseful: aiResult.isUseful,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 20 * 24 * 60 * 60 * 1000)
        ),
      },
      { merge: true }
    );

    savedCount++;
  }

  if (savedCount > 0) {
    await batch.commit();
    await sendJobNewsNotification(savedCount);
  }

  return {
    fetchedCount,
    savedCount,
    skippedCount,
  };
}

exports.fetchJobNews = onSchedule(
  {
    schedule: "0 13 * * *",
    timeZone: "Asia/Tokyo",
    secrets: [NEWS_API_KEY, OPENAI_API_KEY],
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    try {
      const result = await fetchAndSaveNews();
      console.log(
        `Scheduled fetched ${result.fetchedCount}, saved ${result.savedCount}, skipped ${result.skippedCount}`
      );
    } catch (error) {
      console.error(error.response?.data || error.message);
    }
  }
);

exports.testFetchJobNews = onRequest(
  {
    secrets: [NEWS_API_KEY, OPENAI_API_KEY],
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (req, res) => {
    try {
      const result = await fetchAndSaveNews();
      res.status(200).send(
        `Fetched ${result.fetchedCount}, saved ${result.savedCount}, skipped ${result.skippedCount}`
      );
    } catch (error) {
      console.error(error.response?.data || error.message);
      res.status(500).send(error.message);
    }
  }
);
