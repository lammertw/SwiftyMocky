# Known issues

**Please always check, if your problem is not related to feature being not supported** - for that we have **"Supported Features"** section.

-----

## 1. When triggering generation - error about modules in different swift versions appears

This seems to be a problem with Swift abi. Either download/build Sourcery binary manually, or use prebuilt sourcery versions from: `https://github.com/MakeAWishFoundation/SwiftyMocky.wiki.git`

Currentyly we support:

- 3.1
- 4.0
- 4.0.2

**Usage from root project dir:**

```shell
sh get_sourcery.sh 4.0.2
```

**get_sourcery.sh**

```shell
[[ $# > 0 ]] && VERSION="$1" || VERSION="4.0.2"
[[ $# > 1 ]] && OUTPUT="$2" || OUTPUT="./Pods/Sourcery/bin"

echo "CLONE SOURCERY FOR $VERSION INTO $OUTPUT"
rm -r -f "$OUTPUT"
git clone -b "swift/$VERSION" --single-branch --depth 1 https://github.com/MakeAWishFoundation/SwiftyMocky.wiki.git "$OUTPUT"
```

## 2. Matcher [FATAL] error for Equatable / Sequence types

This happens usually for generic mocks - seems that wrapping generic methods causes breaking default resolving of generic contraints, and you might end up seeing something like `[FATAL] No registered matcher comparator for <ValueType>` even when ValueType conforms to Equatable, or is a Collection of objects conforming to Equatable.

As for now - the only valid solution is to add comparators for these types. There are convenience methods on matcher, that allows simple adding of comparators for types conforming to Equatable or Sequence.

See **Generics** section for more informations.

## 3. Generated Mock breaks

When methods has labels or attributes names that are either escaped using  \`, or  are matching Swift keywords like `for, while, guard ...`. For now - we advise not to use that. It will be resolved in the future.
