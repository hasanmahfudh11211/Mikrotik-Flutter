<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

// Koneksi ke database via config terpusat
require_once __DIR__ . '/config.php';

// Ambil data JSON dari input (array of users)
$data = json_decode(file_get_contents("php://input"));

if (!$data || !is_array($data)) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "Invalid data format"]);
    exit();
}

$successCount = 0;
$failedCount = 0;
$failedUsers = [];

foreach ($data as $user) {
    $username = $conn->real_escape_string($user->username ?? '');
    $password = $conn->real_escape_string($user->password ?? '');
    $profile = $conn->real_escape_string($user->profile ?? '');
    $tanggal = date('Y-m-d H:i:s');

    // Cek apakah user sudah ada
    $checkSql = "SELECT id FROM users WHERE username = '$username'";
    $result = $conn->query($checkSql);

    if ($result->num_rows > 0) {
        // Update user yang sudah ada
        $sql = "UPDATE users SET 
                password = '$password',
                profile = '$profile',
                tanggal_dibuat = '$tanggal'
                WHERE username = '$username'";
    } else {
        // Insert user baru
        $sql = "INSERT INTO users (username, password, profile, tanggal_dibuat)
                VALUES ('$username', '$password', '$profile', '$tanggal')";
    }

    if ($conn->query($sql) === TRUE) {
        $successCount++;
    } else {
        $failedCount++;
        $failedUsers[] = [
            'username' => $username,
            'error' => $conn->error
        ];
    }
}

echo json_encode([
    "success" => true,
    "total" => count($data),
    "success_count" => $successCount,
    "failed_count" => $failedCount,
    "failed_users" => $failedUsers
]);

$conn->close();
?>