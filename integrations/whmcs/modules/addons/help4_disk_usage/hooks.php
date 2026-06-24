<?php

if (!defined('WHMCS')) {
    die('This file cannot be accessed directly');
}

use WHMCS\Database\Capsule;
use WHMCS\View\Menu\Item as MenuItem;

add_hook('ClientAreaPrimaryNavbar', 1, function (MenuItem $primaryNavbar) {
    try {
        $enabled = Capsule::table('tbladdonmodules')
            ->where('module', 'help4_disk_usage')
            ->where('setting', 'clientArea')
            ->value('value');
        if ($enabled !== 'on') {
            return;
        }
    } catch (Throwable $e) {
        return;
    }

    if (!$primaryNavbar->getChild('Services')) {
        return;
    }

    $primaryNavbar->getChild('Services')->addChild('Help4 Disk Usage', [
        'label' => 'Disk Usage Reports',
        'uri' => 'index.php?m=help4_disk_usage',
        'order' => 80,
    ]);
});
