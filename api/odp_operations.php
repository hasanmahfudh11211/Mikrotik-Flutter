<?php
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

// $conn disediakan oleh config.php

// Get operation type from query parameter
$operation = isset($_GET['operation']) ? $_GET['operation'] : '';

// Handle POST request for add operation
if ($_SERVER['REQUEST_METHOD'] === 'POST' && $operation === 'add') {
    // Get and decode JSON data
    $rawData = file_get_contents('php://input');
    $data = json_decode($rawData, true);

    // Validate JSON data
    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "error" => "Invalid JSON data: " . json_last_error_msg()
        ]);
        exit();
    }

    // Validate required fields
    if (!isset($data['name']) || !isset($data['location']) || 
        !isset($data['type'])) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "error" => "Missing required fields"
        ]);
        exit();
    }

    // Set default value for maps_link if not provided
    $data['maps_link'] = isset($data['maps_link']) ? $data['maps_link'] : '';

    // Validate type-specific fields
    if ($data['type'] === 'splitter') {
        if (!isset($data['splitter_type'])) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "error" => "Splitter type is required for splitter ODP"
            ]);
            exit();
        }

        // Validate splitter_type value
        $validSplitterTypes = ["1:2", "1:4", "1:8", "1:16"];
        if (!in_array($data['splitter_type'], $validSplitterTypes)) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "error" => "Invalid splitter_type value. Must be one of: " . implode(", ", $validSplitterTypes)
            ]);
            exit();
        }

        // Insert splitter ODP
        $stmt = $conn->prepare(
            "INSERT INTO odp (name, location, maps_link, type, splitter_type, ratio_used, ratio_total) 
             VALUES (?, ?, ?, 'splitter', ?, NULL, NULL)"
        );

        if (!$stmt) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "error" => "Prepare failed: " . $conn->error
            ]);
            exit();
        }

        $stmt->bind_param("ssss", 
            $data['name'],
            $data['location'],
            $data['maps_link'],
            $data['splitter_type']
        );
    } else if ($data['type'] === 'ratio') {
        if (!isset($data['ratio_used']) || !isset($data['ratio_total'])) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "error" => "Ratio values are required for ratio ODP"
            ]);
            exit();
        }

        // Insert ratio ODP
        $stmt = $conn->prepare(
            "INSERT INTO odp (name, location, maps_link, type, splitter_type, ratio_used, ratio_total) 
             VALUES (?, ?, ?, 'ratio', NULL, ?, ?)"
        );

        if (!$stmt) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "error" => "Prepare failed: " . $conn->error
            ]);
            exit();
        }

        $stmt->bind_param("sssii", 
            $data['name'],
            $data['location'],
            $data['maps_link'],
            $data['ratio_used'],
            $data['ratio_total']
        );
    } else {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "error" => "Invalid ODP type. Must be either 'splitter' or 'ratio'"
        ]);
        exit();
    }

    // Execute the prepared statement
    if ($stmt->execute()) {
        echo json_encode([
            "success" => true,
            "message" => "ODP added successfully",
            "odp_id" => $conn->insert_id
        ]);
    } else {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "error" => "Execute failed: " . $stmt->error
        ]);
    }

    $stmt->close();
} 
// Handle POST request for update operation
else if ($_SERVER['REQUEST_METHOD'] === 'POST' && $operation === 'update') {
    // Get and decode JSON data
    $rawData = file_get_contents('php://input');
    $data = json_decode($rawData, true);

    // Validate JSON data
    if (json_last_error() !== JSON_ERROR_NONE || !isset($data['id'])) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "error" => "Invalid JSON data or missing ID"
        ]);
        exit();
    }

    // Validate required fields
    if (!isset($data['name']) || !isset($data['location']) || !isset($data['type'])) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "error" => "Missing required fields"
        ]);
        exit();
    }

    // Set default value for maps_link if not provided
    $data['maps_link'] = isset($data['maps_link']) ? $data['maps_link'] : '';

    if ($data['type'] === 'splitter') {
        if (!isset($data['splitter_type'])) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "error" => "Splitter type is required for splitter ODP"
            ]);
            exit();
        }

        $stmt = $conn->prepare(
            "UPDATE odp SET name = ?, location = ?, maps_link = ?, type = 'splitter', 
             splitter_type = ?, ratio_used = NULL, ratio_total = NULL 
             WHERE id = ?"
        );

        if (!$stmt) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "error" => "Prepare failed: " . $conn->error
            ]);
            exit();
        }

        $stmt->bind_param("ssssi", 
            $data['name'],
            $data['location'],
            $data['maps_link'],
            $data['splitter_type'],
            $data['id']
        );
    } else if ($data['type'] === 'ratio') {
        if (!isset($data['ratio_used']) || !isset($data['ratio_total'])) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "error" => "Ratio values are required for ratio ODP"
            ]);
            exit();
        }

        $stmt = $conn->prepare(
            "UPDATE odp SET name = ?, location = ?, maps_link = ?, type = 'ratio', 
             splitter_type = NULL, ratio_used = ?, ratio_total = ? 
             WHERE id = ?"
        );

        if (!$stmt) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "error" => "Prepare failed: " . $conn->error
            ]);
            exit();
        }

        $stmt->bind_param("sssiii", 
            $data['name'],
            $data['location'],
            $data['maps_link'],
            $data['ratio_used'],
            $data['ratio_total'],
            $data['id']
        );
    }

    // Execute the prepared statement
    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            echo json_encode([
                "success" => true,
                "message" => "ODP updated successfully"
            ]);
        } else {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "error" => "ODP not found"
            ]);
        }
    } else {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "error" => "Execute failed: " . $stmt->error
        ]);
    }

    $stmt->close();
}
// Handle POST request for delete operation
else if ($_SERVER['REQUEST_METHOD'] === 'POST' && $operation === 'delete') {
    // Get and decode JSON data
    $rawData = file_get_contents('php://input');
    $data = json_decode($rawData, true);

    // Validate JSON data
    if (json_last_error() !== JSON_ERROR_NONE || !isset($data['id'])) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "error" => "Invalid JSON data or missing ID"
        ]);
        exit();
    }

    // Prepare and execute delete statement
    $stmt = $conn->prepare("DELETE FROM odp WHERE id = ?");
    
    if (!$stmt) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "error" => "Prepare failed: " . $conn->error
        ]);
        exit();
    }

    $stmt->bind_param("i", $data['id']);

    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            echo json_encode([
                "success" => true,
                "message" => "ODP deleted successfully"
            ]);
        } else {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "error" => "ODP not found"
            ]);
        }
    } else {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "error" => "Execute failed: " . $stmt->error
        ]);
    }

    $stmt->close();
}
// Handle GET request for fetching ODPs
else if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $query = "SELECT * FROM odp ORDER BY name ASC";
    $result = $conn->query($query);

    if ($result) {
        $odp_list = [];
        while ($row = $result->fetch_assoc()) {
            $odp_list[] = $row;
        }
        
        echo json_encode([
            "success" => true,
            "odp_list" => $odp_list
        ]);
    } else {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "error" => "Query failed: " . $conn->error
        ]);
    }
}
// Handle invalid request method
else {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "error" => "Invalid request method or operation"
    ]);
}

// Close database connection
$conn->close();
?>
