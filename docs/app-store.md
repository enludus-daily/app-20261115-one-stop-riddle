# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.010（予定の枠。slots.json は requested のまま。App Store Connect の App は本人が足す） |
| アプリ名 | ひと駅なぞとき：通勤2分の謎解き / One Stop Riddles: Commute |
| サポート URL | https://github.com/enludus-daily/app-20261115-one-stop-riddle/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261115-one-stop-riddle/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」の想定（暴力・ギャンブル・Web 閲覧・生成 AI・ユーザー間の交流なし。物語は落とし物・手紙・試運転で、事件に暴力はない）。4+ の見込み。本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：懐中電灯・効果音・占いなどではない。手で作った 30 問の謎と 3 つの物語を持つゲーム
- 既存のアプリとの意味のある違い：通勤 1 回＝1 問の区切り（便ごとに 1 駅）と、1 週間＝1 事件の物語の単位。路線図を 1 駅ずつ進み、定刻/遅れで記録する
- 長く使える価値（4.2）：3 事件 30 問（日英で別に作成）、定刻率・続いた日・練習、終点の推理
- 他社の名前・商標・見た目を使っていないか：使っていない。路線名・駅名はすべて架空。実在の鉄道会社の路線図・色・記号は使わない
- Apple Intelligence を使う場合、使えない端末での動き：使わない

## 収益の道筋（本人が選ぶ）

- 買い切りの Pro ¥480（`com.enludus.daily.010.pro`、家族共有）。商品は `docs/products.json`、審査用の画像は `docs/iap/paywall.png`（CI のシミュレータでは値段が読めないため「いまは購入できません」の状態。TestFlight の前に撮り直す）
- 理由：README の「課金」（勝算の表）。事件は増え続けないので買い切り

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ。App 内課金は Apple の StoreKit で、アプリは権利の有無だけを見る）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
