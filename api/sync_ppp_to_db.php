<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

// Koneksi ke database via config terpusat
require_once __DIR__ . '/config.php';
$data = json_decode(file_get_contents("php://input"), true);
if (!isset($data['ppp_users']) || !is_array($data['ppp_users'])) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "No PPP user data received"]);
    exit();
}
$added = 0;
foreach ($data['ppp_users'] as $user) {
    $username = $conn->real_escape_string($user['name'] ?? '');
    $password = $conn->real_escape_string($user['password'] ?? '');
    $profile = $conn->real_escape_string($user['profile'] ?? '');
    if (empty($username)) continue;
    // Cek apakah user sudah ada di database
    $stmt = $conn->prepare("SELECT username FROM users WHERE username = ?");
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows == 0) {
        // Insert user baru, data tambahan lain dikosongkan
        $insertStmt = $conn->prepare("INSERT INTO users (username, password, profile, wa, maps, foto, tanggal_dibuat) VALUES (?, ?, ?, '', '', '', NOW())");
        $insertStmt->bind_param("sss", $username, $password, $profile);
        if ($insertStmt->execute()) {
            $added++;
        }
        $insertStmt->close();
    }
    $stmt->close();
}
echo json_encode(["success" => true, "added" => $added]);
$conn->close();
?>
