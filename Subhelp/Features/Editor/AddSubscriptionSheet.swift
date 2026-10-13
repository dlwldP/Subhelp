import SwiftUI

/// [+] 구독 추가 1단계 — 검색 + 카테고리별 프리셋 그리드, 하단 "직접 입력하기"
struct AddSubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    private var query: String { searchText.trimmingCharacters(in: .whitespaces) }

    private var sections: [PresetSection] {
        let all = PresetStore.shared.presets
        let presets = query.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return SubscriptionPreset.grouped(presets)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if sections.isEmpty {
                        Text("‘\(query)’ 검색 결과가 없어요. 아래에서 직접 입력해보세요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.category)
                                .font(.headline)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(section.presets) { preset in
                                    NavigationLink {
                                        editor(SubscriptionDraft(preset: preset))
                                    } label: {
                                        PresetTile(preset: preset)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                NavigationLink {
                    editor(customDraft)
                } label: {
                    Label(query.isEmpty ? "직접 입력하기" : "‘\(query)’ 직접 입력하기", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .controlSize(.large)
                .padding()
                .background(.bar)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "서비스 검색")
            .navigationTitle("구독 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    private func editor(_ draft: SubscriptionDraft) -> some View {
        SubscriptionEditorView(draft: draft, onFinish: { dismiss() })
    }

    private var customDraft: SubscriptionDraft {
        let draft = SubscriptionDraft()
        draft.name = query
        return draft
    }
}

private struct PresetTile: View {
    let preset: SubscriptionPreset

    var body: some View {
        VStack(spacing: 8) {
            InitialIcon(name: preset.name, colorHex: preset.colorHex, size: 44)
            Text(preset.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preset.name)
        .accessibilityAddTraits(.isButton)
    }
}
