# cargo-lambda ビルドキャッシュテスト

cargo-lambda、cargo-chef、sccacheを使用したDockerビルドキャッシュのテスト

## キャッシュ戦略

1. **cargo-chef**: 依存関係のコンパイルとアプリケーションコードを分離
2. **BuildKit cache mounts**: cargoレジストリとgitリポジトリをキャッシュ
3. **sccache**: コンパイル成果物をキャッシュ
4. **mold**: ビルドパフォーマンス向上のための高速リンカ

## プロジェクト構成

```
.
├── lambda/           # Rust Lambda関数 (`cargo lambda new lambda` のまま)
├── Dockerfile        # キャッシュを活用したマルチステージビルド
└── .github/
    └── workflows/
        └── build-test.yml  # 自動ビルドテスト
```

## GitHub Actions CI

ワークフロー（`.github/workflows/build-test.yml`）は以下を自動テストします：

1. キャッシュなしの初回ビルド
2. 完全なキャッシュを使った再ビルド
  1. 一瞬で終わる
3. ソースコード変更後の再ビルド
  1. 初回ビルド時の依存関係のキャッシュを利用し、変更差分のビルドのみで比較的すぐ終る想定

キャッシュの効きは `sccache --show-stats` の結果を参照

## 使用ツール

- [cargo-lambda](https://github.com/cargo-lambda/cargo-lambda)
- [cargo-chef](https://github.com/LukeMathWalker/cargo-chef)
- [sccache](https://github.com/mozilla/sccache)
- [mold](https://github.com/rui314/mold)
