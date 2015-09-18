<?php

include(__DIR__ . '/compare/inc.php');

$report = new report();

if (!empty($_GET['timestamps'])) {

    // Create the report.
    $report->make($_GET['timestamps'], $_GET['threadgroupname']);

}

// Render it.
$renderer = new report_renderer($report);
$renderer->render();
