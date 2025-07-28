//
//  GearViewModel.swift
//  AIGear
//
//  Created by Dastan Sugirbay on 23.06.2025.
//

import Foundation
import SwiftUI
import UIKit

class GearViewModel: ObservableObject {
    static let shared = GearViewModel()
    
    @Published var showChecklist: Bool = false
    @Published var checklistItems: [ChecklistItem] = [] {
        didSet {
            saveChecklistToUserDefaults()
        }
    }
    @Published var shouldNavigateToGear: Bool = false
    
    private let checklistKey = "SavedChecklistItems"
    
    private init() {
        loadChecklistFromUserDefaults()
        setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotificationObservers() {
        // Save when app goes to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveChecklistToUserDefaults()
            print("📱 App went to background - checklist saved")
        }
        
        // Save when app will terminate
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveChecklistToUserDefaults()
            print("📱 App will terminate - checklist saved")
        }
    }
    
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
            // The didSet on checklistItems will automatically save to UserDefaults
        }
    }
    
    func clearChecklist() {
        checklistItems = []
        showChecklist = false
        // Clear from UserDefaults as well
        UserDefaults.standard.removeObject(forKey: checklistKey)
        print("🗑️ Checklist cleared from memory and UserDefaults")
    }
    
    // MARK: - Persistent Storage Methods
    
    private func saveChecklistToUserDefaults() {
        do {
            let encoded = try JSONEncoder().encode(checklistItems)
            UserDefaults.standard.set(encoded, forKey: checklistKey)
            print("✅ Checklist saved to UserDefaults (\(checklistItems.count) items)")
        } catch {
            print("❌ Failed to save checklist: \(error)")
        }
    }
    
    private func loadChecklistFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: checklistKey) else {
            print("📋 No saved checklist found")
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([ChecklistItem].self, from: data)
            self.checklistItems = decoded
            print("✅ Loaded checklist from UserDefaults (\(decoded.count) items)")
        } catch {
            print("❌ Failed to load checklist: \(error)")
        }
    }
    
    // Method to manually save (useful for immediate saves)
    func saveChecklist() {
        saveChecklistToUserDefaults()
    }
    
    // Check if there's a saved checklist
    func hasSavedChecklist() -> Bool {
        return UserDefaults.standard.data(forKey: checklistKey) != nil
    }
    
    // Get count of checked items
    var checkedItemsCount: Int {
        return checklistItems.filter { $0.isChecked }.count
    }
    
    // Get total items count
    var totalItemsCount: Int {
        return checklistItems.count
    }
    

}

struct ChecklistItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: String
    var isChecked: Bool
    
    init(name: String, category: String, isChecked: Bool) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.isChecked = isChecked
    }
}
