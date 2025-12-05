<?php
/**
 * Laravel Droplet - Setup Wizard
 * Upload a Laravel zip, extract it, set permissions, then self-destruct.
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);

$maxSize = 200 * 1024 * 1024; // 200MB
$uploadDir = '/var/www/html';
$message = '';
$error = '';
$success = false;

// Handle upload
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['zipfile'])) {
    $file = $_FILES['zipfile'];
    
    if ($file['error'] !== UPLOAD_ERR_OK) {
        $errors = [
            UPLOAD_ERR_INI_SIZE => 'File exceeds server limit',
            UPLOAD_ERR_FORM_SIZE => 'File exceeds form limit',
            UPLOAD_ERR_PARTIAL => 'File partially uploaded',
            UPLOAD_ERR_NO_FILE => 'No file uploaded',
            UPLOAD_ERR_NO_TMP_DIR => 'No temp directory',
            UPLOAD_ERR_CANT_WRITE => 'Cannot write to disk',
        ];
        $error = $errors[$file['error']] ?? 'Upload error';
    } elseif ($file['size'] > $maxSize) {
        $error = 'File too large (max 200MB)';
    } elseif (pathinfo($file['name'], PATHINFO_EXTENSION) !== 'zip') {
        $error = 'Only .zip files allowed';
    } else {
        $zipPath = '/tmp/laravel-upload.zip';
        
        if (move_uploaded_file($file['tmp_name'], $zipPath)) {
            $zip = new ZipArchive();
            
            if ($zip->open($zipPath) === true) {
                // Find Laravel root (directory containing artisan)
                $laravelRoot = '';
                for ($i = 0; $i < $zip->numFiles; $i++) {
                    $name = $zip->getNameIndex($i);
                    if (basename($name) === 'artisan' && substr_count($name, '/') <= 1) {
                        $laravelRoot = dirname($name);
                        break;
                    }
                }
                
                if ($laravelRoot === '' || $laravelRoot === '.') {
                    // artisan is at root level
                    $zip->extractTo($uploadDir);
                } else {
                    // Extract to temp, then move contents
                    $tempDir = '/tmp/laravel-extract';
                    @mkdir($tempDir, 0755, true);
                    $zip->extractTo($tempDir);
                    
                    // Move Laravel root contents to upload dir
                    $source = $tempDir . '/' . $laravelRoot;
                    $files = new RecursiveIteratorIterator(
                        new RecursiveDirectoryIterator($source, RecursiveDirectoryIterator::SKIP_DOTS),
                        RecursiveIteratorIterator::SELF_FIRST
                    );
                    
                    foreach ($files as $fileInfo) {
                        $target = $uploadDir . '/' . substr($fileInfo->getPathname(), strlen($source) + 1);
                        if ($fileInfo->isDir()) {
                            @mkdir($target, 0755, true);
                        } else {
                            @mkdir(dirname($target), 0755, true);
                            copy($fileInfo->getPathname(), $target);
                        }
                    }
                    
                    // Cleanup temp
                    exec("rm -rf " . escapeshellarg($tempDir));
                }
                
                $zip->close();
                unlink($zipPath);
                
                // Set Laravel permissions
                exec("chown -R www-data:www-data " . escapeshellarg($uploadDir));
                exec("find " . escapeshellarg($uploadDir) . " -type d -exec chmod 755 {} \\;");
                exec("find " . escapeshellarg($uploadDir) . " -type f -exec chmod 644 {} \\;");
                
                // Make artisan executable
                if (file_exists($uploadDir . '/artisan')) {
                    chmod($uploadDir . '/artisan', 0755);
                }
                
                // Storage and bootstrap/cache need to be writable
                if (is_dir($uploadDir . '/storage')) {
                    exec("chmod -R 775 " . escapeshellarg($uploadDir . '/storage'));
                }
                if (is_dir($uploadDir . '/bootstrap/cache')) {
                    exec("chmod -R 775 " . escapeshellarg($uploadDir . '/bootstrap/cache'));
                }
                
                // Final ownership fix
                exec("chown -R www-data:www-data " . escapeshellarg($uploadDir));
                
                // Check if Laravel was installed (artisan file exists)
                if (file_exists($uploadDir . '/artisan')) {
                    $success = true;
                    $message = 'Laravel installed successfully! Redirecting...';
                    // Note: Laravel's public/index.php overwrites this setup wizard automatically
                } else {
                    $error = 'Extraction complete but Laravel artisan not found';
                }
            } else {
                $error = 'Cannot open zip file';
                @unlink($zipPath);
            }
        } else {
            $error = 'Failed to save uploaded file';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Laravel Droplet - Setup</title>
    <?php if ($success): ?>
    <meta http-equiv="refresh" content="2;url=/">
    <?php endif; ?>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: 'SF Pro Display', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #0f0f1a 0%, #1a1a2e 50%, #16213e 100%);
            color: #e8e8e8;
        }
        
        .container {
            text-align: center;
            padding: 3rem;
            max-width: 500px;
            width: 100%;
        }
        
        .logo { font-size: 4rem; margin-bottom: 1rem; }
        
        h1 {
            font-size: 2rem;
            font-weight: 300;
            margin-bottom: 0.5rem;
            letter-spacing: 1px;
        }
        
        .tagline {
            color: #64748b;
            font-size: 1rem;
            margin-bottom: 2rem;
        }
        
        .upload-box {
            background: rgba(255, 255, 255, 0.03);
            border: 2px dashed rgba(255, 255, 255, 0.1);
            border-radius: 16px;
            padding: 2.5rem;
            margin-bottom: 1.5rem;
            transition: all 0.3s ease;
        }
        
        .upload-box:hover, .upload-box.dragover {
            border-color: rgba(99, 102, 241, 0.5);
            background: rgba(99, 102, 241, 0.05);
        }
        
        .upload-icon {
            font-size: 3rem;
            margin-bottom: 1rem;
            opacity: 0.7;
        }
        
        .upload-text {
            color: #94a3b8;
            margin-bottom: 1rem;
        }
        
        .upload-hint {
            color: #475569;
            font-size: 0.8rem;
        }
        
        input[type="file"] { display: none; }
        
        .btn {
            display: inline-block;
            background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
            color: white;
            padding: 0.875rem 2rem;
            border: none;
            border-radius: 50px;
            font-size: 1rem;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.3s ease;
            text-decoration: none;
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 30px rgba(99, 102, 241, 0.3);
        }
        
        .btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
            transform: none;
        }
        
        .file-name {
            margin-top: 1rem;
            padding: 0.75rem 1rem;
            background: rgba(99, 102, 241, 0.1);
            border-radius: 8px;
            color: #a5b4fc;
            font-size: 0.9rem;
            display: none;
        }
        
        .file-name.show { display: block; }
        
        .message {
            padding: 1rem;
            border-radius: 12px;
            margin-bottom: 1.5rem;
            font-size: 0.9rem;
        }
        
        .message.error {
            background: rgba(239, 68, 68, 0.1);
            border: 1px solid rgba(239, 68, 68, 0.3);
            color: #fca5a5;
        }
        
        .message.success {
            background: rgba(16, 185, 129, 0.1);
            border: 1px solid rgba(16, 185, 129, 0.3);
            color: #6ee7b7;
        }
        
        .progress {
            display: none;
            margin-top: 1.5rem;
        }
        
        .progress.show { display: block; }
        
        .progress-bar {
            height: 6px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 3px;
            overflow: hidden;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #6366f1, #8b5cf6);
            width: 0%;
            transition: width 0.3s ease;
        }
        
        .progress-text {
            color: #64748b;
            font-size: 0.8rem;
            margin-top: 0.5rem;
        }
        
        .spinner {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 2px solid rgba(255,255,255,0.3);
            border-radius: 50%;
            border-top-color: white;
            animation: spin 1s linear infinite;
            margin-right: 8px;
            vertical-align: middle;
        }
        
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">📦</div>
        <h1>Laravel Droplet</h1>
        <p class="tagline">Upload your Laravel application</p>
        
        <?php if ($error): ?>
        <div class="message error"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>
        
        <?php if ($success): ?>
        <div class="message success">
            <span class="spinner"></span>
            <?= htmlspecialchars($message) ?>
        </div>
        <?php else: ?>
        
        <form method="POST" enctype="multipart/form-data" id="uploadForm">
            <div class="upload-box" id="dropZone">
                <div class="upload-icon">☁️</div>
                <p class="upload-text">Drag & drop your Laravel <strong>.zip</strong> file here</p>
                <p class="upload-hint">or click to browse (max 200MB)</p>
                <input type="file" name="zipfile" id="fileInput" accept=".zip" required>
            </div>
            
            <div class="file-name" id="fileName"></div>
            
            <button type="submit" class="btn" id="submitBtn" disabled>
                Upload & Install
            </button>
            
            <div class="progress" id="progress">
                <div class="progress-bar">
                    <div class="progress-fill" id="progressFill"></div>
                </div>
                <p class="progress-text" id="progressText">Uploading...</p>
            </div>
        </form>
        
        <?php endif; ?>
    </div>
    
    <script>
        const dropZone = document.getElementById('dropZone');
        const fileInput = document.getElementById('fileInput');
        const fileName = document.getElementById('fileName');
        const submitBtn = document.getElementById('submitBtn');
        const uploadForm = document.getElementById('uploadForm');
        const progress = document.getElementById('progress');
        const progressFill = document.getElementById('progressFill');
        const progressText = document.getElementById('progressText');
        
        // Click to upload
        dropZone.addEventListener('click', () => fileInput.click());
        
        // Drag & drop
        dropZone.addEventListener('dragover', (e) => {
            e.preventDefault();
            dropZone.classList.add('dragover');
        });
        
        dropZone.addEventListener('dragleave', () => {
            dropZone.classList.remove('dragover');
        });
        
        dropZone.addEventListener('drop', (e) => {
            e.preventDefault();
            dropZone.classList.remove('dragover');
            const files = e.dataTransfer.files;
            if (files.length && files[0].name.endsWith('.zip')) {
                fileInput.files = files;
                updateFileName(files[0]);
            }
        });
        
        // File selected
        fileInput.addEventListener('change', () => {
            if (fileInput.files.length) {
                updateFileName(fileInput.files[0]);
            }
        });
        
        function updateFileName(file) {
            const sizeMB = (file.size / 1024 / 1024).toFixed(1);
            fileName.textContent = `${file.name} (${sizeMB} MB)`;
            fileName.classList.add('show');
            submitBtn.disabled = false;
        }
        
        // Form submit with progress
        uploadForm.addEventListener('submit', (e) => {
            e.preventDefault();
            
            const formData = new FormData(uploadForm);
            const xhr = new XMLHttpRequest();
            
            xhr.upload.addEventListener('progress', (e) => {
                if (e.lengthComputable) {
                    const percent = Math.round((e.loaded / e.total) * 100);
                    progressFill.style.width = percent + '%';
                    progressText.textContent = percent < 100 ? `Uploading... ${percent}%` : 'Extracting & setting permissions...';
                }
            });
            
            xhr.addEventListener('load', () => {
                document.body.innerHTML = xhr.responseText;
            });
            
            xhr.open('POST', '', true);
            xhr.send(formData);
            
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<span class="spinner"></span> Uploading...';
            progress.classList.add('show');
        });
    </script>
</body>
</html>

