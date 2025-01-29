import ComposableArchitecture
import SwiftUI

struct HomeTCAView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Text("Home screen placeholder")
        }
    }
}
