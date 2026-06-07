import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    var carPlayManager = CarPlayManager()
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        carPlayManager.templateApplicationScene(templateApplicationScene, didConnect: interfaceController)
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        carPlayManager.templateApplicationScene(templateApplicationScene, didDisconnectInterfaceController: interfaceController)
    }
}
