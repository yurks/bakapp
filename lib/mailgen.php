<?php

ini_set('error_reporting', E_ALL);
ini_set("display_errors", 1);
ini_set("log_errors", 0);

require('class.phpmailer.php');

function println($str = '')
{
    print $str . PHP_EOL;
}

function exitWithUsage($info = '', $cmd = '')
{
    $info = trim($info);
    if ($info) {
        println($info);
    }
    if ($cmd) {
        println();
        println('Usage:');
        println('    echo "Mail body" | ' . $cmd . ' -r recipient [options...]');
        println();
        println('Options:');
        println('    -r recipient     mail recipient');
        println('    -s subject       mail subject');
        println('    -f from_address  mail from address');
        println();
        println('Mail body:');
        println('    Multi-line mail body. Could contain lines starting with "@@MAILGEN:<key>@@"');
        println();
        println('    @@MAILGEN:attachment@@filename.ext');
        println('    @@MAILGEN:attachment@@/optional/path_to/project/filename.ext');
        println('        attach content as file with "filename.ext"');
        println('        and set message subject to "project/filename.ext" if path specified');
        println();
        println('    @@MAILGEN:subject@@Mail subject');
        println('        generate mail with "Mail subject" if no cli option provided');
        println();
        println('    @@MAILGEN:recipient@@Mail recipient');
        println('        add "Mail recipient" in addition to cli option provided');
    }
    println(' ');
    exit(1);
}


function marcher($str, &$params)
{
    $pattern = '/^@@MAILGEN:([^@]+)@@(.*)$/';
    if (preg_match($pattern, $str)) {
        preg_match($pattern, $str, $matches);
        if (count($matches) === 3) {

            $params[$matches[1]] = $matches[2];
        }
        return TRUE;
    };
    return FALSE;
}

function getSTDIN()
{
    $stdin = fopen('php://stdin', 'r');
    #stream_set_blocking($stdin, FALSE);
    $out = '';
    $params = array();
    while ($f = fgets($stdin)) {
        if (!marcher($f, $params)) {
            $out .= $f;
        }
    }
    fclose($stdin);
    return array($out, $params);
}

function getoptFix($opt, &$options, $delimiter = NULL) {
    if (!array_key_exists($opt, $options)) {
        $options[$opt] = NULL;
    }
    settype($options[$opt], 'array');
    if ($delimiter !== NULL) {
        if (gettype($delimiter) === 'integer') {
            $options[$opt] = array_key_exists($delimiter, $options[$opt]) ? $options[$opt][$delimiter] : '';
        } else {
            $options[$opt] = implode (' ', $options[$opt]);
        }
    }
    return $options[$opt];
}

function getProp($opt, &$array) {
    if (array_key_exists($opt, $array)) {
        return $array[$opt];
    }
    return NULL;
}

function generateMail(&$content, &$options, &$props)
{
    $mail = new PHPMailer(true);
    $out = '';
    try {
        $mail->CharSet = "UTF-8";
        //$mail->setFrom('from@example.com', 'First Last');
        foreach ($options['r'] as $value) {
            $mail->addAddress($value);
        }
        //$mail->msgHTML('<html><body><pre>' . htmlspecialchars($content) . '</pre></body></html>', dirname(__FILE__));
        //$mail->AltBody = $content;

        $prop = getProp('attachment', $props);
        if ($prop) {
            $path = pathinfo($prop);
            $filename = $path['basename'];
            $mail->Subject = $filename;
            if (array_key_exists('dirname', $path)) {
                $path = pathinfo($path['dirname']);
                if ($path['basename'] && $path['basename'] !== '.') {
                    $mail->Subject = $path['basename'] . '/' . $filename;
                }
            }
            $mail->addStringAttachment($content, $filename);
            $mail->AllowEmpty = true;
        } else {
            $mail->Body = $content;
        }

        $prop = getProp('subject', $props);
        if ($prop) {
            $mail->Subject = $prop;
        }
        if ($options['s']) {
            $mail->Subject = str_replace('@subject@', $mail->Subject ? $mail->Subject : '', $options['s']);
        }

        $prop = getProp('recipient', $props);
        if ($prop) {
            $mail->addAddress($prop);
        }

        $mail->preSend();
        $out = trim($mail->getSentMIMEMessage());

    } catch (phpmailerException $e) {
        exitWithUsage($e->getMessage());

    } catch (Exception $e) {
        exitWithUsage($e->getMessage());
    }
    if (!$out) {
        exitWithUsage('Something wrong!');
    }
    return $out;
}

$cmd = getenv('_ACTUAL_BIN');
if (!$cmd) {
    $cmd = 'php ' . $argv[0];
}

$options = getopt("f:s:r:");

getoptFix('r', $options);
getoptFix('s', $options, ' ');
getoptFix('f', $options, 0);

if (!count($options['r'])) {
    exitWithUsage('', $cmd);
}

$body = getSTDIN();
$content = $body[0];
if (!$content) {
    exitWithUsage('', $cmd);
}

println(generateMail($content, $options, $body[1]));
