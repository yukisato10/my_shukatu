import GoogleMobileAds
import UIKit
import google_mobile_ads
class NativeAdFactory: NSObject, FLTNativeAdFactory {

    func createNativeAd(
        _ nativeAd: NativeAd,
        customOptions: [AnyHashable : Any]? = nil
    ) -> NativeAdView {

        let nibView = Bundle.main.loadNibNamed(
            "NativeAdView",
            owner: nil,
            options: nil
        )?.first

        guard let nativeAdView = nibView as? NativeAdView else {
            fatalError("NativeAdView.xib not found")
        }

        nativeAdView.nativeAd = nativeAd

        // Headline
        (nativeAdView.headlineView as? UILabel)?.text =
            nativeAd.headline

        // Body
        (nativeAdView.bodyView as? UILabel)?.text =
            nativeAd.body

        nativeAdView.bodyView?.isHidden =
            nativeAd.body == nil

        // Icon
        (nativeAdView.iconView as? UIImageView)?.image =
            nativeAd.icon?.image

        nativeAdView.iconView?.isHidden =
            nativeAd.icon == nil

        // CTA
        (nativeAdView.callToActionView as? UIButton)?.setTitle(
            nativeAd.callToAction,
            for: .normal
        )

        nativeAdView.callToActionView?.isHidden =
            nativeAd.callToAction == nil

        nativeAdView.callToActionView?.isUserInteractionEnabled = false

        return nativeAdView
    }
}
