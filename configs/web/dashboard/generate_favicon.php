<?php
/**
 * Generate LDS Dashboard Favicon
 * Creates a flame-style favicon with the LDS red brand palette
 */

// Check if GD extension is available
if (!extension_loaded('gd')) {
    die("GD extension is required to generate favicon\n");
}

// Create a 32x32 image
$size = 32;
$img = imagecreatetruecolor($size, $size);

// LDS Brand Palette
$bgColor      = imagecolorallocate($img, 0x0f, 0x14, 0x19);  // --bg:#0f1419
$redBright    = imagecolorallocate($img, 0xEF, 0x44, 0x44);  // #EF4444
$redMid       = imagecolorallocate($img, 0xDC, 0x26, 0x26);  // #DC2626
$redDark      = imagecolorallocate($img, 0xB9, 0x1C, 0x1C);  // #B91C1C
$redDeep      = imagecolorallocate($img, 0x99, 0x1B, 0x1B);  // #991B1B
$redSoft      = imagecolorallocate($img, 0xFC, 0xA5, 0xA5);  // #FCA5A5
$redPale      = imagecolorallocate($img, 0xFE, 0xF2, 0xF2);  // #FEF2F2
$transparent  = imagecolorallocatealpha($img, 0, 0, 0, 127);

// Fill background with transparent
imagefill($img, 0, 0, $transparent);
imagesavealpha($img, true);

// Draw flame shape (simplified for 32x32)
// Center at (16, 16), flame pointing up

// Outer flame (dark red)
$points = [
    16, 2,   // top
    26, 10,  // right upper
    28, 18,  // right mid
    26, 26,  // right lower
    16, 30,  // bottom
    6, 26,   // left lower
    4, 18,   // left mid
    6, 10,   // left upper
];
imagefilledpolygon($img, $points, 8, $redDark);

// Inner flame (bright red)
$points2 = [
    16, 6,   // top
    24, 12,  // right upper
    26, 18,  // right mid
    24, 24,  // right lower
    16, 28,  // bottom
    8, 24,   // left lower
    6, 18,   // left mid
    8, 12,   // left upper
];
imagefilledpolygon($img, $points2, 8, $redBright);

// Core flame (soft red)
$points3 = [
    16, 10,  // top
    21, 14,  // right upper
    22, 18,  // right mid
    21, 22,  // right lower
    16, 25,  // bottom
    11, 22,  // left lower
    10, 18,  // left mid
    11, 14,  // left upper
];
imagefilledpolygon($img, $points3, 8, $redSoft);

// Center highlight (pale red)
imagefilledellipse($img, 16, 20, 6, 8, $redPale);

// Save as ICO
function createICO($img, $filename) {
    $width = imagesx($img);
    $height = imagesy($img);
    
    // Get PNG data
    ob_start();
    imagepng($img);
    $pngData = ob_get_clean();
    
    // ICO header
    $icoHeader = pack('vvv', 0, 1, 1); // Reserved, Type (1=ICO), Count (1 image)
    
    // ICO directory entry
    $icoDir = pack('CCCCvvII', 
        $width,      // Width
        $height,     // Height
        0,           // Color palette
        0,           // Reserved
        1,           // Color planes
        32,          // Bits per pixel
        strlen($pngData), // Size of image data
        22           // Offset to image data (6 + 16)
    );
    
    // Write ICO file
    file_put_contents($filename, $icoHeader . $icoDir . $pngData);
}

// Generate ICO
createICO($img, 'favicon.ico');

// Also save as PNG for reference
imagepng($img, 'favicon.png');

imagedestroy($img);

echo "Generated LDS flame favicon.ico and favicon.png\n";
echo "Size: " . filesize('favicon.ico') . " bytes\n";
echo "Colors: LDS Red (#EF4444 → #991B1B)\n";
