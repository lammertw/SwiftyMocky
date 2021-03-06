//
//  Parameter.swift
//  Pods
//
//  Created by przemyslaw.wosko on 19/05/2017.
//
//

import Foundation

/// Parameter wraps method attribute, allowing to make a difference between explicit value,
/// expressed by `.value` case and wildcard value, expressed by `.any` case.
///
/// Whole idea is to be able to test and specify behaviours, in both generic and explicit way
/// (and any mix of these two). Every test method matches mock methods in signature, but changes attributes types
/// to Parameter.
///
/// That allows pattern like matching between two Parameter values:
/// - **.any** is equal to every other parameter. (**!!!** actual case name is `._`, but it is advised to use `.any`)
/// - **.value(p1)** is equal to **.value(p2)** only, when p1 == p2
///
/// **Important!** Comparing parameters, where ValueType is not Equatable will result in fatalError,
/// unless you register comparator for its *ValueType* in **Matcher** instance used (typically Matcher.default)
///
/// - any: represents and matches any parameter value
/// - value: represents explicit parameter value
public enum Parameter<ValueType> {
    /// Wildcard - any value
    case `_`
    /// Explicit value
    case value(ValueType)
    /// Any value matching
    case matching((ValueType) -> Bool)

    /// Represents and matches any parameter value - syntactic sugar for `._` case.
    public static var any: Parameter<ValueType> { return Parameter<ValueType>._ }

    /// Represents and matches any parameter value - syntactic sugar for `._` case. Used, when needs to explicitely specify
    /// wrapped *ValueType* type, to resolve ambiguity between methods with same signatures, but different attribute types.
    ///
    /// - Parameter type: Explicitly specify ValueType type
    /// - Returns: any parameter
    public static func any<T>(_ type: T.Type) -> Parameter<T> {
        return Parameter<T>._
    }
}

// MARK: - Order
public extension Parameter {
    /// Used for invocations sorting purpose.
    public var intValue: Int {
        switch self {
            case ._: return 0
            case .value: return 1
            case .matching: return 1
        }
    }
}

//// MARK: - Equality
public extension Parameter {
    /// Returns whether given two parameters are matching each other, with following rules:
    ///
    /// 1. if parameter is .any - it is equal to any other parameter
    /// 2. if both are .value - then compare wrapped ValueType instances.
    /// 3. if they are not Equatable (or not a Sequences of Equatable), use provided matcher instance
    ///
    /// - Parameters:
    ///   - lhs: First parameter
    ///   - rhs: Second parameter
    ///   - matcher: Matcher instance
    /// - Returns: true, if first is matching second
    public static func compare(lhs: Parameter<ValueType>, rhs: Parameter<ValueType>, with matcher: Matcher) -> Bool {
        switch (lhs, rhs) {
            case (._, _): return true
            case (_, ._): return true
            case (.matching(let match), .value(let value)): return match(value)
            case (.value(let value), .matching(let match)): return match(value)
            case (.value(let lhsValue), .value(let rhsValue)):
                guard let compare = matcher.comparator(for: ValueType.self) else {
                    print("[FATAL] No registered matcher comparator for \(String(describing: ValueType.self))")
                    fatalError("No registered comparators for \(String(describing: ValueType.self))")
                }
                return compare(lhsValue,rhsValue)
            default: return false
        }
    }

    /// [Internal] Wraps as generic Parameter instance. Should not be ever called directly.
    ///
    /// - Returns: Wrapped parameter
    public func wrapAsGeneric() -> Parameter<GenericAttribute> {
        switch self {
            case ._:
                let attribute = GenericAttribute(Mirror(reflecting: ValueType.self), { (l, r, m) -> Bool in
                    guard let lv = l as? Mirror else { return false }
                    if let rv = r as? Mirror {
                        return lv.subjectType == rv.subjectType
                    } else if let _ = r as? ValueType {
                        return true // .any comparing .value or .matching
                    } else {
                        return false
                    }
                })
                return Parameter<GenericAttribute>.value(attribute)
            case let .value(value):
                let attribute = GenericAttribute(value, { (l, r, m) -> Bool in
                    guard let lv = l as? ValueType  else { return false }
                    if let rv = r as? ValueType {
                        let lhs = Parameter<ValueType>.value(lv)
                        let rhs = Parameter<ValueType>.value(rv)
                        return Parameter<ValueType>.compare(lhs: lhs, rhs: rhs, with: m)
                    } else if let rv = r as? ((ValueType) -> Bool) {
                        return rv(lv)
                    } else if let rv = r as? Mirror {
                        return Mirror(reflecting: ValueType.self).subjectType == rv.subjectType
                    } else {
                        return false
                    }
                })
                return Parameter<GenericAttribute>.value(attribute)
            case let .matching(match):
                let attribute = GenericAttribute(match, { (l, r, m) -> Bool in
                    guard let lv = l as? ((ValueType) -> Bool)  else { return false }
                    if let rv = r as? ValueType {
                        let lhs = Parameter<ValueType>.matching(lv)
                        let rhs = Parameter<ValueType>.value(rv)
                        return Parameter<ValueType>.compare(lhs: lhs, rhs: rhs, with: m)
                    } else if let rv = r as? Mirror {
                        return Mirror(reflecting: ValueType.self).subjectType == rv.subjectType
                    } else {
                        return false
                    }
                })
                return Parameter<GenericAttribute>.value(attribute)
        }
    }
}

public extension Parameter where ValueType: GenericAttributeType {
    public static func compare(lhs: Parameter<ValueType>, rhs: Parameter<ValueType>, with matcher: Matcher) -> Bool {
        switch (lhs, rhs) {
            case (._, _): return true
            case (_, ._): return true
            case (.value(let lhsGeneric), .value(let rhsGeneric)): return lhsGeneric.compare(lhsGeneric.value,rhsGeneric.value,matcher)
            default: return false
        }
    }
}

public extension Parameter where ValueType: Equatable {
    public static func compare(lhs: Parameter<ValueType>, rhs: Parameter<ValueType>, with matcher: Matcher) -> Bool {
        switch (lhs, rhs) {
            case (._, _): return true
            case (_, ._): return true
            case (.matching(let match), .value(let value)): return match(value)
            case (.value(let value), .matching(let match)): return match(value)
            case let (.value(left), .value(right)): return left == right
            default: return false
        }
    }
}

public extension Parameter where ValueType: Sequence {
#if swift(>=3.2)
    typealias Element = ValueType.Element
#else
    typealias Element = ValueType.Iterator.Element
#endif

    public static func compare(lhs: Parameter<ValueType>, rhs: Parameter<ValueType>, with matcher: Matcher) -> Bool {
        switch (lhs, rhs) {
            case (._, _): return true
            case (_, ._): return true
            case (.matching(let match), .value(let value)): return match(value)
            case (.value(let value), .matching(let match)): return match(value)
            case (.value(let lhsSequence), .value(let rhsSequence)):
                let leftArray = lhsSequence.map { $0 }
                let rightArray = rhsSequence.map { $0 }

                guard leftArray.count == rightArray.count else { return false }

                let values = (0..<leftArray.count)
                .map { i -> (Element, Element) in
                    return ((leftArray[i]),(rightArray[i]))
                }

                guard let comparator = matcher.comparator(for: Element.self) else {
                    print("[FATAL] No registered matcher comparator for \(Element.self)")
                    fatalError("Not registered comparator for \(Element.self)")
                }

                for (left,right) in values {
                    guard comparator(left, right) else {
                        return false
                    }
                }

                return true
            default: return false
        }
    }

    public func wrapAsGeneric() -> Parameter<GenericAttribute> {
        switch self {
            case ._:
                let attribute = GenericAttribute(Mirror(reflecting: ValueType.self), { (l, r, m) -> Bool in
                    guard let lv = l as? Mirror else { return false }
                    if let rv = r as? Mirror {
                        return lv.subjectType == rv.subjectType
                    } else if let _ = r as? ValueType {
                        return true // .any comparing .value
                    } else {
                        return false
                    }
                })
                return Parameter<GenericAttribute>.value(attribute)
            case let .value(value):
                let attribute = GenericAttribute(value, { (l, r, m) -> Bool in
                    guard let lv = l as? ValueType  else { return false }
                    if let rv = r as? ValueType {
                        let lhs = Parameter<ValueType>.value(lv)
                        let rhs = Parameter<ValueType>.value(rv)
                        return Parameter<ValueType>.compare(lhs: lhs, rhs: rhs, with: m)
                    } else if let rv = r as? ((ValueType) -> Bool) {
                        return rv(lv)
                    } else if let rv = r as? Mirror {
                        return Mirror(reflecting: ValueType.self).subjectType == rv.subjectType
                    } else {
                        return false
                    }
                })
                return Parameter<GenericAttribute>.value(attribute)
            case let .matching(match):
                let attribute = GenericAttribute(match, { (l, r, m) -> Bool in
                    guard let lv = l as? ((ValueType) -> Bool)  else { return false }
                    if let rv = r as? ValueType {
                        let lhs = Parameter<ValueType>.matching(lv)
                        let rhs = Parameter<ValueType>.value(rv)
                        return Parameter<ValueType>.compare(lhs: lhs, rhs: rhs, with: m)
                    } else if let rv = r as? Mirror {
                        return Mirror(reflecting: ValueType.self).subjectType == rv.subjectType
                    } else {
                        return false
                    }
                })
                return Parameter<GenericAttribute>.value(attribute)
        }
    }
}

#if swift(>=3.2)
public extension Parameter where ValueType: Sequence, ValueType.Element: Equatable {
    public static func compare(lhs: Parameter<ValueType>, rhs: Parameter<ValueType>, with matcher: Matcher) -> Bool {
        switch (lhs, rhs) {
            case (._, _): return true
            case (_, ._): return true
            case (.matching(let match), .value(let value)): return match(value)
            case (.value(let value), .matching(let match)): return match(value)
            case (.value(let lhsSequence), .value(let rhsSequence)):
                let leftArray = lhsSequence.map { $0 }
                let rightArray = rhsSequence.map { $0 }

                guard leftArray.count == rightArray.count else { return false }

                let values = (0..<leftArray.count)
                .map { i -> (ValueType.Element, ValueType.Element) in
                    return ((leftArray[i]),(rightArray[i]))
                }

                for (left,right) in values {
                    guard left == right else { return false }
                }

                return true
            default: return false
        }
    }
}

public extension Parameter where ValueType: Sequence, ValueType.Element: Equatable, ValueType: Equatable {
    public static func compare(lhs: Parameter<ValueType>, rhs: Parameter<ValueType>, with matcher: Matcher) -> Bool {
        switch (lhs, rhs) {
            case (._, _): return true
            case (_, ._): return true
            case (.matching(let match), .value(let value)): return match(value)
            case (.value(let value), .matching(let match)): return match(value)
            case let (.value(left), .value(right)): return left == right
            default: return false
        }
    }
}
#else
public extension Parameter where ValueType: Sequence, ValueType.Iterator.Element: Equatable {
    public static func compare(lhs: Parameter<ValueType>, rhs: Parameter<ValueType>, with matcher: Matcher) -> Bool {
        switch (lhs, rhs) {
            case (._, _): return true
            case (_, ._): return true
            case (.matching(let match), .value(let value)): return match(value)
            case (.value(let value), .matching(let match)): return match(value)
            case (.value(let lhsSequence), .value(let rhsSequence)):
                let leftArray = lhsSequence.map { $0 }
                let rightArray = rhsSequence.map { $0 }

                guard leftArray.count == rightArray.count else { return false }

                let values = (0..<leftArray.count)
                .map { i -> (ValueType.Iterator.Element, ValueType.Iterator.Element) in
                    return ((leftArray[i]),(rightArray[i]))
                }

                for (left,right) in values {
                    guard left == right else { return false }
                }

                return true
            default: return false
        }
    }
}

public extension Parameter where ValueType: Sequence, ValueType.Iterator.Element: Equatable, ValueType: Equatable {
    public static func compare(lhs: Parameter<ValueType>, rhs: Parameter<ValueType>, with matcher: Matcher) -> Bool {
        switch (lhs, rhs) {
            case (._, _): return true
            case (_, ._): return true
            case (.matching(let match), .value(let value)): return match(value)
            case (.value(let value), .matching(let match)): return match(value)
            case let (.value(left), .value(right)): return left == right
            default: return false
        }
    }
}
#endif
