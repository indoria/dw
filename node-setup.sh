#!/bin/bash

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Setup Node.js environment
setup_node() {
    if command_exists node; then
        echo "Node.js is already installed. Version: $(node -v)"
    else
        # Install NVM if not already installed
        if ! command_exists nvm; then
            echo "Installing NVM..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
            # Load nvm into the current shell session
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        fi

        # Install the latest stable Node.js version
        echo "Installing the latest stable version of Node.js..."
        nvm install --lts
        nvm use --lts
        nvm alias default node
    fi

    # Check npm installation and update npm if needed
    if command_exists npm; then
        echo "Updating npm to the latest version..."
        npm install -g npm
    fi
}

# Install or update ffmpeg
setup_ffmpeg() {
    if command_exists ffmpeg; then
        echo "ffmpeg is already installed. Updating to the latest version..."
        sudo apt update && sudo apt install -y ffmpeg
    else
        echo "Installing ffmpeg..."
        sudo apt update && sudo apt install -y ffmpeg
    fi
    echo "ffmpeg version: $(ffmpeg -version | head -n 1)"
}

# Initialize project dependencies
setup_project_dependencies() {
    if [ ! -f "package.json" ]; then
        echo "Initializing Node.js project..."
        npm init -y
    fi

    # Install required dependencies
    declare -a dependencies=("express" "dotenv" "axios")  # Regular dependencies
    for pkg in "${dependencies[@]}"; do
        if ! npm list "$pkg" &>/dev/null; then
            echo "Installing $pkg..."
            npm install "$pkg"
        else
            echo "$pkg is already installed."
        fi
    done

    # Install dev dependencies, including nodemon
    declare -a devDependencies=("jest" "supertest" "nodemon")  # Dev dependencies, including nodemon
    for devPkg in "${devDependencies[@]}"; do
        if ! npm list "$devPkg" &>/dev/null; then
            echo "Installing $devPkg as a dev dependency..."
            npm install --save-dev "$devPkg"
        else
            echo "$devPkg is already installed as a dev dependency."
        fi
    done
}

# Set up directory structure
setup_directory_structure() {
    echo "Setting up project directory structure..."

    mkdir -p src/{controllers,routes,services,utils,middlewares,config}
    mkdir -p public
    mkdir -p storage
    mkdir -p tests/{unit,integration}

    # Update server.js content
    echo -e "const app = require('./app');\n\nconst PORT = 80;\n\napp.listen(PORT, () => {\n    console.log(\`Server is running on http://localhost:\${PORT}\`);\n});" > src/server.js

    # Update app.js content
    echo -e "const express = require('express');\nconst path = require('path');\nconst app = express();\n\napp.use(express.json());\napp.use(express.static(path.join(__dirname, '..', 'public')));\napp.use('/storage', express.static(path.join(__dirname, '..', 'storage')));\n\napp.post('/process-url', async (req, res) => {\n    const { endURL } = req.body;\n\n    if (!endURL) {\n        return res.status(400).json({ error: 'endURL is required' });\n    }\n\n    console.log('Received endURL:', endURL);\n\n    try {\n        res.json({ message: 'Download successful', filePath });\n    } catch (error) {\n        res.status(500).json({ error: 'Failed to download video', details: error });\n    }\n});\n\nmodule.exports = app;" > src/app.js

    # Create index.html file in public folder
    cat <<EOL > public/index.html
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Video Downloader</title>
    <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
</head>

<body>
    <h1>Enter a URL</h1>
    <div>
        <input type="text" id="urlInput" placeholder="Enter URL">
        <button onclick="sendURL()">Submit</button>
    </div>

    <div>
        <input type="text" id="playInput" placeholder="https://path/to/file.m3u8">
        <button onclick="playInput()">play</button>
    </div>

    <p id="responseMessage"></p>
    <video id="video" controls width="640" height="360"></video>

    <script>
        async function sendURL() {
            const urlInput = document.getElementById('urlInput').value;
            const responseMessage = document.getElementById('responseMessage');

            try {
                const response = await fetch('/process-url', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ endURL: urlInput }),
                });

                const data = await response.json();

                if (response.ok) {
                    responseMessage.textContent = `Server Response: ${data.message}`;
                } else {
                    responseMessage.textContent = `Error: ${data.error}`;
                }
            } catch (error) {
                responseMessage.textContent = 'Request failed. Please try again.';
            }
        }


        function playInput() {
        const video = document.getElementById('video');
        const videoSrc = document.getElementById('playInput').value;

        if (Hls.isSupported()) {
            const hls = new Hls();
            hls.loadSource(videoSrc);
            hls.attachMedia(video);
            hls.on(Hls.Events.MANIFEST_PARSED, function () {
                video.play();
            });
        } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
            video.src = videoSrc;
            video.addEventListener('loadedmetadata', function () {
                video.play();
            });
        }

        }
    </script>
</body>

</html>
EOL

    echo "Directory structure and files setup completed."
}

# Add scripts to package.json
update_package_scripts() {
    echo "Updating package.json scripts..."

    # Check if jq is installed
    if ! command_exists jq; then
        echo "jq is not installed. Installing jq..."
        sudo apt-get update && sudo apt-get install -y jq
    fi

    # Add start and dev scripts to package.json
    jq '.scripts += {"start": "node src/server.js", "dev": "nodemon src/server.js"}' package.json > tmp.json && mv tmp.json package.json

    echo "Scripts added to package.json successfully."
}

# Run setup functions
setup_node
setup_ffmpeg
setup_project_dependencies
setup_directory_structure
update_package_scripts

echo "Setup completed successfully."