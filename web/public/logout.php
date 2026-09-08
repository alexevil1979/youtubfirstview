<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';
auth_start($config);
auth_logout();
redirect('/login.php');
