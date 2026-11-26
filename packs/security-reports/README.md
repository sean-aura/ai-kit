# Pack: security-reports

House-style prompts for drafting security assurance documents: gap analyses,
security risk assessments, environment reviews, executive summaries, a findings
quality check and an open-items register.

Every prompt in this pack starts with `prompts/_rules.md`, which tells the model to
cite a source for every statement, write NOT EVIDENCED instead of guessing, and end
every output with **Missing or unknown**, **Next steps** and **Risks not yet managed**.

## Use

```bash
ai prompt security-reports/gap-analysis      # copy to clipboard for the chat window
cat evidence.md | ai ask write -p security-reports/findings-qa   # or straight from the terminal
```

Use **local mode** for client material (`ai mode` shows the current mode).

## Suggested workflow

1. OCR any scanned PDFs first (`ai ocr scan.pdf`). A scan with no text layer is invisible to the model.
2. Copy the prompt for the report type and paste it into a new chat (`ai chat write`).
3. Attach the evidence and your framework or rating scale.
4. Review the draft against the sources, then run `findings-qa` to flag unsupported claims.
5. Run `open-items` over the finished draft for one register of gaps, next steps and unmanaged risks.
6. Save the final text as Markdown and run `ai docx draft.md template.docx`.
7. At the end of the engagement run `ai wipe`.

## Long documents

The chat window usually retrieves **excerpts** of uploaded files rather than reading them
whole (files under about 50,000 characters are now read in full by Open WebUI 0.13+).
A "not covered" answer can simply mean the relevant section was not retrieved.

- Treat every "not found" as a prompt to check, not a finding.
- Work in batches (the gap-analysis prompt does this) and keep each batch small.
- For one key document, paste the relevant section directly instead of uploading it.
- Spot-check cited sources against the originals. Always.

## Still to add

- Your OSA template and rating scales (the prompts ask for your scale rather than assume one).
- Your Word template for `ai docx`.
