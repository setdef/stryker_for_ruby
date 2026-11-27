# Stryker (for Ruby)

> [!NOTE]  
> **Stryker (for Ruby)** is a community port that is not affiliated with [Stryker Mutator](https://stryker-mutator.io). We hope to upstream **Stryker (for Ruby)** and become an official project of the [Stryker Mutator organization](https://github.com/stryker-mutator) when this library is ready for release.


## Introduction

**Stryker (for Ruby)** is a mutation testing framework for [Ruby](https://www.ruby-lang.org/en/) and [erb](https://docs.ruby-lang.org/en/master/ERB.html). It allows you to test your tests by temporarily inserting bugs.

For an introduction to mutation testing and [Stryker Mutator](https://stryker-mutator.io)'s features, see [stryker-mutator.io](https://stryker-mutator.io/). Looking for mutation testing in [JavaScript](https://github.com/stryker-mutator/stryker), [.NET](https://github.com/stryker-mutator/stryker-net), or [Scala](https://github.com/stryker-mutator/stryker4s)?

> [!WARNING]  
> **Stryker (for Ruby)** is currently in an early stage of development. Use at your own risk.

## Compatibility

**Stryker (for Ruby)** supports Ruby 4.0 and later. Ruby 3.3 and 3.4 may work, but they are unsupported, and [the problems found on them](./docs/older-ruby.md) are listed. Because [Prism](https://github.com/ruby/prism) only supports parsing Ruby 3.3 and later, **Stryker (for Ruby)** will not add support for older versions of Ruby.

## Configuration

For the full list of configuration options available in **Stryker (for Ruby)**, see the [configuration docs](./docs/configuration.md).


## Supported Mutations

For the full list of all available mutations, see [the catalog of mutators](./docs/contributors/design/mutators.md#the-catalog).


## Copyright & License

**Stryker (for Ruby)** is copyright 2026, setdef. **Stryker (for Ruby)** is licensed under the Apache License 2.0; see [LICENSES/Apache-2.0.txt](./LICENSES/Apache-2.0.txt) for the full text.

Some parts of this program are copied from other sources under appropriate reuse licenses, and the copyright belongs to their respective owners. See the [REUSE Specification – Version 3.3](https://reuse.software/spec-3.3/) for information about how we comply with attribution and licensing requirements.
