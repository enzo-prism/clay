import Foundation
import Testing
@testable import ClayFeature

@Test func settingsState_defaultsAnimatedBackgroundsEnabledToTrue() throws {
    let data = Data(
        """
        {
          "offlineCapDays": 7,
          "notificationsEnabled": true,
          "colorblindMode": false,
          "use3DPreviews": true,
          "guidanceLevel": "high"
        }
        """.utf8
    )
    let decoded = try JSONDecoder().decode(SettingsState.self, from: data)
    #expect(decoded.animatedBackgroundsEnabled == true)
}

@Test func backgroundVideoAsset_mapsEraIdsToExpectedAssetNames() {
    #expect(BackgroundVideoAsset.assetName(forEraId: "stone") == "bg_stone")
    #expect(BackgroundVideoAsset.assetName(forEraId: "agrarian") == "bg_stone")
    #expect(BackgroundVideoAsset.assetName(forEraId: "industrial") == "bg_industrial")
    #expect(BackgroundVideoAsset.assetName(forEraId: "stellar") == "bg_stellar")
    #expect(BackgroundVideoAsset.assetName(forEraId: "galactic") == "bg_stellar")
}
