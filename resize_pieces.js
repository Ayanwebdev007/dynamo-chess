const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const directory = 'assets/pieces';

fs.readdirSync(directory).forEach(file => {
    if (file.endsWith('.png')) {
        const inputPath = path.join(directory, file);
        const tempPath = path.join(directory, 'temp_' + file);

        console.log(`Resizing ${file}...`);

        sharp(inputPath)
            .resize(256, 256)
            .toFile(tempPath)
            .then(() => {
                fs.unlinkSync(inputPath);
                fs.renameSync(tempPath, inputPath);
                console.log(`Successfully resized ${file}`);
            })
            .catch(err => {
                console.error(`Error resizing ${file}:`, err);
            });
    }
});
