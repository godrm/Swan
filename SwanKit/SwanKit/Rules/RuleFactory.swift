import Foundation

struct RuleFactory {
    
    /// Filter disabledRules and create rule
    /// - Parameter disabledRules: The TuleTypes need to disable
    static func make() -> [Rule] {
        let rules: [RuleType]
        rules = RuleType.allCases
        return rules.map(RuleFactory.make)
    }
    
    static func make(_ type: RuleType) -> Rule {
        switch type {
        case .skipPublic:
            return SkipPublicRule()
        case .xctest:
            return XCTestRule()
        case .attributes:
            return AttributesRule()
        case .comment:
            return CommentRule()
        case .superClass:
            var superClassRule = SuperClassRule()
            superClassRule.blacklist = []
            return superClassRule
        case .skipOptionaFunction:
            return SkipOptionalFunctionRule()
        }
    }
}
