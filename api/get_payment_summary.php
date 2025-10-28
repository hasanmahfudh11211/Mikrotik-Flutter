<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Koneksi ke database via config terpusat
require_once __DIR__ . '/config.php';

// Query summary pembayaran per bulan/tahun
$sql = "SELECT payment_month, payment_year, SUM(amount) as total, COUNT(*) as count FROM payments GROUP BY payment_year, payment_month ORDER BY payment_year DESC, payment_month DESC";
$result = $conn->query($sql);

$summary = [];
while ($row = $result->fetch_assoc()) {
    $summary[] = [
        'month' => intval($row['payment_month']),
        'year' => intval($row['payment_year']),
        'total' => floatval($row['total']),
        'count' => intval($row['count'])
    ];
}

echo json_encode(["success" => true, "data" => $summary]);
$conn->close();
exit(); 