import SwiftUI

struct TripSpecView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var days: Int
    @Binding var overnight: Bool
    @Binding var season: String
    @Binding var companions: Int
    
    var onSave: () -> Void
    
    private let seasons = ["summer", "winter", "shoulder"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Trip Length")) {
                    Stepper(value: $days, in: 1...30) {
                        Text("\(days) day\(days > 1 ? "s" : "")")
                    }
                }
                
                Section(header: Text("Overnight")) {
                    Toggle("Includes overnight camping", isOn: $overnight)
                }
                
                Section(header: Text("Season")) {
                    Picker("Season", selection: $season) {
                        ForEach(seasons, id: \.self) { s in
                            Text(displayName(for: s)).tag(s)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Party Size")) {
                    Stepper(value: $companions, in: 1...12) {
                        Text("\(companions) person\(companions > 1 ? "s" : "")")
                    }
                }
            }
            .navigationTitle("Trip Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

extension TripSpecView {
    func displayName(for season: String) -> String {
        switch season {
        case "winter":
            return "Winter"
        case "summer":
            return "Summer"
        case "shoulder":
            return "Shoulder"
        default:
            return season.capitalized
        }
    }
} 