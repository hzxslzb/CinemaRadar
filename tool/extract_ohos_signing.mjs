import fs from 'node:fs';

const [sourcePath, localPath] = process.argv.slice(2);
if (!sourcePath || !localPath) {
  throw new Error('Usage: extract_ohos_signing.mjs <source> <local-output>');
}

const profile = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const signingConfigs = profile?.app?.signingConfigs;
if (!Array.isArray(signingConfigs) || signingConfigs.length === 0) {
  throw new Error('No signing configuration was generated.');
}

const privateProfile = {app: {signingConfigs}};
fs.writeFileSync(localPath, `${JSON.stringify(privateProfile, null, 2)}\n`, {
  encoding: 'utf8',
  mode: 0o600,
});
fs.chmodSync(localPath, 0o600);

profile.app.signingConfigs = [];
fs.writeFileSync(sourcePath, `${JSON.stringify(profile, null, 2)}\n`, 'utf8');
console.log('Stored the local OHOS signing configuration and sanitized the project profile.');
