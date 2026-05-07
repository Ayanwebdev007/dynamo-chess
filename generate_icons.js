const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const iconSource = 'assets/dynamo_logo.png';
const resDir = 'android/app/src/main/res';

const targets = [
    { folder: 'mipmap-mdpi', size: 48 },
    { folder: 'mipmap-hdpi', size: 72 },
    { folder: 'mipmap-xhdpi', size: 96 },
    { folder: 'mipmap-xxhdpi', size: 144 },
    { folder: 'mipmap-xxxhdpi', size: 192 }
];

async function generateIcons() {
    if (!fs.existsSync(iconSource)) {
        console.error('Source icon not found: ' + iconSource);
        process.exit(1);
    }

    for (const target of targets) {
        const targetFolder = path.join(resDir, target.folder);
        if (!fs.existsSync(targetFolder)) {
            fs.mkdirSync(targetFolder, { recursive: true });
        }

        const targetPath = path.join(targetFolder, 'ic_launcher.png');
        const targetRoundPath = path.join(targetFolder, 'ic_launcher_round.png');

        console.log(`Generating ${target.size}x${target.size} icon for ${target.folder}...`);

        try {
            // Standard icon
            await sharp(iconSource)
                .resize(target.size, target.size)
                .toFile(targetPath);

            // Round icon (manual fallback)
            await sharp(iconSource)
                .resize(target.size, target.size)
                .toFile(targetRoundPath);

            console.log(`✓ Success: ${target.folder}`);
        } catch (err) {
            console.error(`✗ Error generating for ${target.folder}:`, err);
        }
    }
}

generateIcons();
