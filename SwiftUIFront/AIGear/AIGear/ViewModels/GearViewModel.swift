//
//  GearViewModel.swift
//  AIGear
//
//  Created by Dastan Sugirbay on 23.06.2025.
//

import Foundation
import SwiftUI

class GearViewModel: ObservableObject {
    static let shared = GearViewModel()
    
    @Published var showChecklist: Bool = false
    @Published var checklistItems: [ChecklistItem] = []
    @Published var shouldNavigateToGear: Bool = false
    
    private init() {}
    
    func createChecklistFromRecommendations(_ recommendations: String) {
        // Parse the recommendations text and detect categories
        let lines = recommendations.components(separatedBy: "\n")
        var items: [ChecklistItem] = []
        var currentCategory: String = "Other"
        let headerRegex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*:")

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            // Detect category headers like **Clothing:**
            if let match = headerRegex?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
                if let range = Range(match.range(at: 1), in: line) {
                    currentCategory = String(line[range])
                    continue
                }
            }
            // Bullet item
            if line.hasPrefix("•") {
                let itemName = line.dropFirst(1).trimmingCharacters(in: .whitespaces)
                items.append(ChecklistItem(name: itemName, category: currentCategory, isChecked: false))
            }
        }
        self.checklistItems = items
        
        // 📦 Merge with PackWizard backpacking checklist essentials
        let packWizardExtras: [String] = [
            "Tent", "Sleeping bag", "Sleeping pad", "Stove", "Fuel", "Cookware",
            "Water filter", "Water reservoir", "Trowel (cat-hole)", "Trash bag",
            "Map", "Compass", "GPS / Phone", "Headlamp", "Extra batteries",
            "Fire starter", "Sunscreen", "Insect repellent", "Lip balm",
            "Duct tape", "Multi-tool", "Repair kit", "Whistle", "Bear hang / Canister"
        ]

        for extra in packWizardExtras {
            if !self.checklistItems.contains(where: { $0.name.localizedCaseInsensitiveContains(extra) }) {
                // Simple category mapping
                let equipmentSet: Set<String> = ["Tent", "Sleeping bag", "Sleeping pad", "Stove", "Fuel", "Cookware", "Water filter", "Water reservoir", "Trowel (cat-hole)", "Trash bag", "Bear hang / Canister"]
                let navSet: Set<String> = ["Map", "Compass", "GPS / Phone"]
                let safetySet: Set<String> = ["Headlamp", "Extra batteries", "Fire starter", "Whistle"]
                let healthSet: Set<String> = ["Sunscreen", "Insect repellent", "Lip balm"]
                let repairSet: Set<String> = ["Duct tape", "Multi-tool", "Repair kit"]

                var cat = "Other"
                if equipmentSet.contains(extra) { cat = "Equipment" }
                else if navSet.contains(extra) { cat = "Navigation" }
                else if safetySet.contains(extra) { cat = "Safety" }
                else if healthSet.contains(extra) { cat = "Health" }
                else if repairSet.contains(extra) { cat = "Repair" }

                self.checklistItems.append(ChecklistItem(name: extra, category: cat, isChecked: false))
            }
        }
        
        self.showChecklist = true
    }
    
    func toggleItem(id: UUID) {
        if let idx = checklistItems.firstIndex(where: { $0.id == id }) {
            checklistItems[idx].isChecked.toggle()
        }
    }
    
    func clearChecklist() {
        checklistItems = []
        showChecklist = false
    }
}

struct ChecklistItem: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    var isChecked: Bool
}
