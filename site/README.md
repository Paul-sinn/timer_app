# Hatcho — 호스팅용 정적 페이지

App Store 제출에 필요한 **공개 URL 2개**(개인정보처리방침·지원)를 위한 페이지.

- `privacy.html` → Privacy Policy URL
- `support.html` → Support URL
- `index.html` → 랜딩(선택, 마케팅 URL로 써도 됨)

앱소스와 분리하려고 **별도 공개 repo**에 올리는 걸 권장(예: `hatcho-site`).

## 방법 A — GitHub 웹 업로드 (git 불필요, 제일 쉬움)
1. github.com/new → 이름 `hatcho-site`, **Public**, Create.
2. "uploading an existing file" 클릭 → 이 폴더의 `index.html`·`privacy.html`·`support.html` 3개 드래그 → Commit.
3. repo → **Settings → Pages** → Source: *Deploy from a branch* → Branch: `main` / `/ (root)` → Save.
4. 1~2분 뒤 URL 생성:
   - `https://paul-sinn.github.io/hatcho-site/privacy.html`
   - `https://paul-sinn.github.io/hatcho-site/support.html`

## 방법 B — git CLI
```bash
# site/ 3파일을 빈 폴더로 복사 후:
cd <빈폴더>
git init && git add . && git commit -m "Hatcho legal pages"
git branch -M main
git remote add origin https://github.com/paul-sinn/hatcho-site.git
git push -u origin main
# 그다음 Settings → Pages 에서 main/root 활성화 (방법 A의 3~4단계)
```

## App Store Connect에 넣기
- **Privacy Policy URL** = `.../privacy.html`
- **Support URL** = `.../support.html`
- (선택) **Marketing URL** = `.../index.html`

> Pages URL은 대소문자·경로 정확히. 브라우저에서 먼저 열어 200 확인 후 붙여넣기.
