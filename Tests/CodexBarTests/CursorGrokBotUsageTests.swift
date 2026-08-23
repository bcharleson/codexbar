import Foundation
import Testing
@testable import CodexBarCore

@Suite(.serialized)
struct CursorGrokBotUsageTests {
    // MARK: - GetSandUsageStatus Response Parsing

    @Test
    func `parses grok bot usage status response`() throws {
        let json = """
        {
            "currentPeriodStart": "2026-08-18T18:00:05.066Z",
            "nextResetTimestampUtc": "2026-08-25T18:00:05.066Z",
            "usagePercent": 100,
            "hasAvailableUsage": true,
            "hasNonZeroIncludedLimit": true,
            "onDemandSettings": {
                "visible": true,
                "eligible": true,
                "enabled": true,
                "dashboardUrl": "https://cursor.com/dashboard/spending"
            },
            "grokPlanLabel": "Grok Bot Plan"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let status = try JSONDecoder().decode(CursorGrokBotUsageStatus.self, from: data)

        #expect(status.usagePercent == 100)
        #expect(status.grokPlanLabel == "Grok Bot Plan")
        #expect(status.hasNonZeroIncludedLimit == true)
        #expect(status.resetsAt != nil)
    }

    @Test
    func `parses omitted usage percent as zero`() throws {
        // proto3 omits zero-valued scalar fields; a fresh week reports no usage_percent.
        let json = """
        {
            "nextResetTimestampUtc": "2026-09-01T18:00:00Z",
            "hasAvailableUsage": true
        }
        """
        let data = try #require(json.data(using: .utf8))
        let status = try JSONDecoder().decode(CursorGrokBotUsageStatus.self, from: data)

        #expect(status.usagePercent == nil)
    }

    // MARK: - Snapshot Window Wiring

    private func makeSnapshot() -> CursorStatusSnapshot {
        CursorStatusSnapshot(
            planPercentUsed: 42,
            planUsedUSD: 10,
            planLimitUSD: 100,
            onDemandUsedUSD: 0,
            onDemandLimitUSD: nil,
            teamOnDemandUsedUSD: nil,
            teamOnDemandLimitUSD: nil,
            billingCycleEnd: Date(timeIntervalSince1970: 1_800_000_000),
            membershipType: "ultra",
            accountEmail: "test@example.com",
            accountName: "Test",
            rawJSON: nil)
    }

    @Test
    func `attaches grok bot extra rate window to snapshot`() throws {
        let status = CursorGrokBotUsageStatus(
            usagePercent: 100,
            currentPeriodStart: nil,
            nextResetTimestampUtc: "2026-08-25T18:00:05.066Z",
            hasAvailableUsage: true,
            hasNonZeroIncludedLimit: true,
            grokPlanLabel: "Grok Bot Plan")
        let snapshot = makeSnapshot().withGrokBotWindow(status)

        #expect(snapshot.grokBotWeeklyPercentUsed == 100)
        #expect(snapshot.grokBotPlanLabel == "Grok Bot Plan")
        let windows = try #require(snapshot.toUsageSnapshot().extraRateWindows)
        #expect(windows.count == 1)
        #expect(windows[0].id == "grokbot-weekly")
        #expect(windows[0].title == "Grok Bot")
        #expect(windows[0].window.usedPercent == 100)
        #expect(windows[0].window.resetsAt == status.resetsAt)
    }

    @Test
    func `clamps out of range grok bot percent`() throws {
        let status = CursorGrokBotUsageStatus(
            usagePercent: 137.5,
            currentPeriodStart: nil,
            nextResetTimestampUtc: nil,
            hasAvailableUsage: true,
            hasNonZeroIncludedLimit: true,
            grokPlanLabel: nil)
        let snapshot = makeSnapshot().withGrokBotWindow(status)

        #expect(snapshot.grokBotWeeklyPercentUsed == 100)
        let windows = snapshot.toUsageSnapshot().extraRateWindows
        #expect(windows?[0].window.usedPercent == 100)
    }

    @Test
    func `snapshot without grok bot window has none`() {
        let snapshot = makeSnapshot()
        #expect(snapshot.grokBotWeeklyPercentUsed == nil)
        #expect(snapshot.toUsageSnapshot().extraRateWindows == nil)
    }
}
