<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';
auth_start($config);

if (auth_check()) {
    redirect('/dashboard.php');
}
redirect('/login.php');
