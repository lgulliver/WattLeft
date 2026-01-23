# Contributing

Thanks for helping improve WattLeft!

## Development

1. Install Xcode (current stable).
2. Install XcodeGen:

```bash
brew install xcodegen
```

3. Generate the project:

```bash
xcodegen
```

4. Open `WattLeft.xcodeproj` in Xcode.

## Tests

```bash
xcodebuild test -project WattLeft.xcodeproj -scheme WattLeft -destination "platform=macOS"
```

## Pull Requests

- Keep PRs focused and small when possible.
- Include a clear description of the change and any UI impact.
- Add or update tests for logic changes.

## License

By contributing, you agree that your contributions will be licensed under the GPL-3.0 License.
