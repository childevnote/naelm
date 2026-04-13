//
//  FeedbackView.swift
//  Naelm
//
//  개선사항 전송 — 텍스트 입력 후 개발자에게 이메일 전송
//

import SwiftUI
import MessageUI

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var feedbackText: String = ""
    @State private var showMailComposer: Bool = false
    @State private var showMailUnavailableAlert: Bool = false
    @State private var showSentConfirmation: Bool = false

    private let developerEmail = "childevnote@gmail.com"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer().frame(height: 8)

                // 아이콘
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(AppPalette.forest)

                VStack(spacing: 8) {
                    Text("개선사항 보내기")
                        .font(.title2).fontWeight(.bold)
                    Text("앱 사용 중 불편하거나 개선이 필요한 점을\n자유롭게 작성해주세요.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // 텍스트 입력
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                // 전송 버튼
                Button {
                    sendFeedback()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                        Text("전송하기")
                    }
                    .font(.headline).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? Color.gray
                                  : AppPalette.forest)
                    )
                }
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("개선사항")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(
                    recipient: developerEmail,
                    subject: "[Naelm] 개선사항 피드백",
                    body: feedbackText,
                    onResult: { result in
                        if result == .sent {
                            showSentConfirmation = true
                            feedbackText = ""
                        }
                    }
                )
            }
            .alert("메일 전송 불가", isPresented: $showMailUnavailableAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("이 기기에서 메일 전송이 불가합니다.\n설정에서 메일 계정을 추가해주세요.")
            }
            .alert("전송 완료", isPresented: $showSentConfirmation) {
                Button("확인") { dismiss() }
            } message: {
                Text("소중한 의견 감사합니다!\n검토 후 반영하겠습니다.")
            }
        }
    }

    private func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            showMailUnavailableAlert = true
        }
    }
}

// MARK: - Mail Composer UIKit Wrapper

struct MailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    var onResult: ((MFMailComposeResult) -> Void)? = nil

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var onResult: ((MFMailComposeResult) -> Void)?

        init(onResult: ((MFMailComposeResult) -> Void)?) {
            self.onResult = onResult
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onResult?(result)
            controller.dismiss(animated: true)
        }
    }
}
