//
//  NaelmUITests.swift
//  NaelmUITests
//
//  Created by 김동진 on 4/3/26.
//

import XCTest

final class NaelmUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testSignInShowsFriendlyErrorForRealFailureInjection() throws {
        throw XCTSkip("실패 경로는 Apple 시스템 인증 결과 주입 훅이 필요해 현재는 수동 QA 체크리스트로 검증합니다.")
    }

    @MainActor
    func testSignInSuppressesErrorForCanceledInjection() throws {
        throw XCTSkip("취소 경로는 Apple 시스템 시트 자동화 제약으로 수동 QA 체크리스트에서 검증합니다.")
    }

    @MainActor
    func testSignInAppleSystemSheetCancelIsManualCheck() throws {
        throw XCTSkip("Sign in with Apple 시스템 시트는 자동화 제약이 있어 수동 심사 체크리스트로 검증합니다.")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
