import SwiftUI

/// + 버튼 → 프리셋 선택 → 편집 폼
struct AddSubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var presets: [SubscriptionPreset] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return SubscriptionPreset.all }
        return SubscriptionPreset.all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SubscriptionEditorView(draft: customDraft, onFinish: { dismiss() })
                    } label: {
                        Label(searchText.isEmpty ? "직접 입력" : "‘\(searchText)’ 직접 입력", systemImage: "square.and.pencil")
                    }
                }

                if !presets.isEmpty {
                    Section("자주 쓰는 구독") {
                        ForEach(presets) { preset in
                            NavigationLink {
                                SubscriptionEditorView(draft: SubscriptionDraft(preset: preset), onFinish: { dismiss() })
                            } label: {
                                HStack(spacing: 12) {
                                    InitialIcon(name: preset.name, colorHex: preset.colorHex, size: 32)
                                    Text(preset.name)
                                    Spacer()
                                    Text(preset.category)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "서비스 검색")
            .navigationTitle("구독 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    private var customDraft: SubscriptionDraft {
        let draft = SubscriptionDraft()
        draft.name = searchText.trimmingCharacters(in: .whitespaces)
        return draft
    }
}
