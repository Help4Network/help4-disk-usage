<?php

namespace WHMCS\Database {
    class Capsule
    {
        public static $services = [];
        public static $reports = [];
        public static function table($name) { return new TestQuery($name); }
    }

    class TestQuery
    {
        private $name;
        private $filters = [];
        private $maximum = PHP_INT_MAX;
        public function __construct($name) { $this->name = $name; }
        public function select(...$columns) { return $this; }
        public function orderBy(...$args) { return $this; }
        public function limit($limit) { $this->maximum = $limit; return $this; }
        public function on(...$args) { return $this; }
        public function join($table, $callback) { $callback($this); return $this; }
        public function where($key, $value)
        {
            $this->filters[] = function ($row) use ($key, $value) { return ($row[$key] ?? null) == $value; };
            return $this;
        }
        public function whereIn($key, $values)
        {
            $this->filters[] = function ($row) use ($key, $values) { return in_array($row[$key] ?? null, $values, true); };
            return $this;
        }
        public function get()
        {
            $rows = Capsule::$services;
            if ($this->name !== 'tblhosting') {
                $rows = [];
                foreach (Capsule::$reports as $report) {
                    foreach (Capsule::$services as $service) {
                        if ($report['service_id'] == $service['id']
                            && $report['whmcs_server_id'] == $service['server']
                            && $report['username'] === $service['username']) {
                            $rows[] = $report + ['h.userid' => $service['userid'],
                                'h.domainstatus' => $service['domainstatus'], 'current_domain' => $service['domain']];
                        }
                    }
                }
            }
            foreach ($this->filters as $filter) { $rows = array_values(array_filter($rows, $filter)); }
            return array_map(function ($row) { return (object)$row; }, array_slice($rows, 0, $this->maximum));
        }
    }
}

namespace {
    define('WHMCS', true);
    require dirname(__DIR__) . '/integrations/whmcs/modules/addons/help4_disk_usage/help4_disk_usage.php';
    use WHMCS\Database\Capsule;

    function check($condition, $message) { if (!$condition) { throw new RuntimeException($message); } }
    function service($id, $client, $state, $server = 6, $username = 'reused')
    {
        return ['id' => $id, 'userid' => $client, 'domainstatus' => $state, 'server' => $server,
            'username' => $username, 'domain' => 'example.test', 'regdate' => '2026-10-01'];
    }
    Capsule::$services = [service(10, 1, 'Terminated'), service(20, 2, 'Active'), service(30, 3, 'Active', 7)];
    check(help4_disk_usage_find_service(6, 'reused')->id === 20, 'historical customer selected for reused username');
    check(help4_disk_usage_find_service(7, 'reused')->id === 30, 'server binding lost');
    check(help4_disk_usage_find_service(6, 'missing') === null, 'unmapped username acquired an owner');
    check(!help4_disk_usage_scan_matches_service('2026-09-30', (object)Capsule::$services[1]), 'pre-provisioning report accepted');
    check(help4_disk_usage_scan_matches_service('2026-10-02', (object)Capsule::$services[1]), 'current report rejected');
    check(!help4_disk_usage_scan_matches_service('invalid', (object)Capsule::$services[1]), 'invalid scan time accepted');

    Capsule::$reports = [
        ['service_id' => 10, 'whmcs_server_id' => 6, 'username' => 'reused', 'domain' => 'old.test', 'scanned_at' => '2026-10-02'],
        ['service_id' => 20, 'whmcs_server_id' => 6, 'username' => 'reused', 'domain' => 'new.test', 'scanned_at' => '2026-10-02'],
        ['service_id' => 30, 'whmcs_server_id' => 7, 'username' => 'reused', 'domain' => 'other.test', 'scanned_at' => '2026-10-02'],
    ];
    $vars = ['clientArea' => 'on'];
    $_SESSION['uid'] = 1;
    check(help4_disk_usage_clientarea($vars)['vars']['accounts'] === [], 'former customer saw fresh report');
    $_SESSION['uid'] = 2;
    check(count(help4_disk_usage_clientarea($vars)['vars']['accounts']) === 1, 'current customer report missing');
    $currentRows = help4_disk_usage_clientarea($vars)['vars']['accounts'];
    check($currentRows[0]['service_url'] === 'clientarea.php?action=productdetails&id=20', 'service link bound to wrong account');
    foreach (['../victim', '/etc/passwd', 'x//y', "x\nheader", 'x\\y'] as $path) {
        check(!help4_disk_usage_safe_relative_path($path), 'unsafe WHMCS report path accepted');
    }
    $details = help4_disk_usage_report_details(['large_files_json' => json_encode([
        ['relative_path' => '../victim', 'bytes' => 1], ['relative_path' => 'public_html/odd # & file.log', 'bytes' => 20],
    ])]);
    check(count($details['large_files']) === 1 && strpos($details['coverage'], 'unknown') !== false, 'legacy report path/coverage unsafe');
    $_SESSION['uid'] = 99;
    check(help4_disk_usage_clientarea($vars)['vars']['accounts'] === [], 'unrelated client saw report');
    Capsule::$services[] = service(40, 4, 'Active');
    check(help4_disk_usage_find_service(6, 'reused') === null, 'ambiguous service mapping accepted');
    $_SESSION['uid'] = 2;
    check(help4_disk_usage_clientarea($vars)['vars']['accounts'] === [], 'existing ambiguous association remained visible');
    array_pop(Capsule::$services);
    Capsule::$services[1]['domainstatus'] = 'Suspended';
    check(help4_disk_usage_find_service(6, 'reused')->id === 20, 'suspended current service should remain entitled');
    Capsule::$services[1]['domainstatus'] = 'Cancelled';
    check(help4_disk_usage_clientarea($vars)['vars']['accounts'] === [], 'cancelled customer saw report');
    unset($_SESSION['uid']);
    check(help4_disk_usage_clientarea($vars)['vars']['accounts'] === [], 'anonymous report exposure');
    echo "WHMCS tenant isolation tests passed\n";
}
