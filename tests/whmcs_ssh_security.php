<?php

namespace phpseclib\Net {
    class SSH2
    {
        public static $publicKey = '';
        public static $loginCalls = 0;

        public function __construct($host, $port, $timeout)
        {
        }

        public function getServerPublicHostKey()
        {
            return self::$publicKey;
        }

        public function login($user, $password)
        {
            self::$loginCalls++;
            return $user === 'root' && $password === 'test-secret';
        }

        public function setTimeout($timeout)
        {
        }

        public function exec($command, $callback)
        {
            if (!preg_match('/(__H4DU_EXIT_[0-9a-f]{24}__)/', $command, $matches)) {
                return false;
            }
            $callback("bounded output\n" . $matches[1] . ":0\n");
            return true;
        }

        public function isTimeout()
        {
            return false;
        }
    }
}

namespace {
    define('WHMCS', true);

    function decrypt($value)
    {
        return $value === 'encrypted' ? 'test-secret' : '';
    }

    require dirname(__DIR__) . '/integrations/whmcs/modules/addons/help4_disk_usage/help4_disk_usage.php';

    function h4du_assert($condition, $message)
    {
        if (!$condition) {
            fwrite(STDERR, $message . "\n");
            exit(1);
        }
    }

    $embeddedAlgorithm = 'ssh-rsa';
    $blob = pack('N', strlen($embeddedAlgorithm)) . $embeddedAlgorithm . pack('N', 3) . "\x01\x00\x01" . str_repeat("k", 64);
    $publicKey = 'rsa-sha2-512 ' . base64_encode($blob);
    $rawFingerprint = hash('sha256', $blob, true);
    $openSshFingerprint = 'SHA256:' . rtrim(base64_encode($rawFingerprint), '=');

    h4du_assert(hash_equals($rawFingerprint, help4_disk_usage_public_host_key_fingerprint_raw($publicKey)), 'valid RSA SHA-2 host key was rejected');
    h4du_assert(help4_disk_usage_fingerprint_matches($openSshFingerprint, $rawFingerprint), 'OpenSSH fingerprint did not match');
    h4du_assert(help4_disk_usage_fingerprint_matches(bin2hex($rawFingerprint), $rawFingerprint), 'hex fingerprint did not match');
    h4du_assert(help4_disk_usage_public_host_key_fingerprint_raw('not-a-key') === false, 'malformed host key was accepted');

    $mismatchedBlob = pack('N', 11) . 'ssh-ed25519' . str_repeat("x", 64);
    $mismatchedKey = 'ssh-rsa ' . base64_encode($mismatchedBlob);
    h4du_assert(help4_disk_usage_public_host_key_fingerprint_raw($mismatchedKey) === false, 'mismatched host-key algorithm was accepted');

    \phpseclib\Net\SSH2::$publicKey = $publicKey;
    $server = (object)[
        'hostname' => 'test.invalid',
        'ipaddress' => '',
        'username' => 'root',
        'password' => 'encrypted',
    ];
    $result = help4_disk_usage_phpseclib_ssh_exec(
        'phpseclib\\Net\\SSH2',
        $server->hostname,
        22,
        $server->username,
        decrypt($server->password),
        'printf bounded',
        $openSshFingerprint,
        false,
        30
    );
    h4du_assert(!empty($result['ok']) && $result['output'] === 'bounded output', 'pinned phpseclib command failed');
    h4du_assert(\phpseclib\Net\SSH2::$loginCalls === 1, 'valid pin did not authenticate exactly once');

    \phpseclib\Net\SSH2::$loginCalls = 0;
    $blocked = help4_disk_usage_phpseclib_ssh_exec(
        'phpseclib\\Net\\SSH2',
        $server->hostname,
        22,
        $server->username,
        decrypt($server->password),
        'printf blocked',
        'SHA256:wrong',
        false,
        30
    );
    h4du_assert(empty($blocked['ok']), 'mismatched pin was accepted');
    h4du_assert(\phpseclib\Net\SSH2::$loginCalls === 0, 'authentication ran before host-key rejection');

    echo "WHMCS SSH security test passed\n";
}
