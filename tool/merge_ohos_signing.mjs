import fs from 'node:fs';

const [templatePath, localPath, outputPath] = process.argv.slice(2);
if (!templatePath || !localPath || !outputPath) {
  throw new Error('Expected template, local signing config, and output paths.');
}

const template = JSON.parse(fs.readFileSync(templatePath, 'utf8'));
const local = JSON.parse(fs.readFileSync(localPath, 'utf8'));
const signingConfigs = local?.app?.signingConfigs;
if (!Array.isArray(signingConfigs) || signingConfigs.length === 0) {
  throw new Error('The local signing config does not contain signingConfigs.');
}

template.app.signingConfigs = signingConfigs;
fs.writeFileSync(outputPath, `${JSON.stringify(template, null, 2)}\n`, {
  mode: 0o600,
});
