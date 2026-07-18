package Cpanel::Template;

use strict;
use warnings;

sub process_template {
    my ($service, $vars) = @_;
    die "unexpected template service\n" unless $service eq 'whostmgr';
    die "unexpected template file\n" unless ($vars->{template_file} || '') eq 'help4_disk_usage/index.tmpl';
    die "template output must print\n" unless $vars->{print};

    my $content = $vars->{page_content} || '';
    die "standalone document nested in WHM content\n" if $content =~ /<!doctype|<html\b|<body\b/i;
    my $title = $vars->{page_title} || 'Help4 Disk Usage';
    print '<!doctype html><html><head><title>WHM ' . $title . '</title></head><body>'
        . '<nav id="whm-left-navigation">WHM navigation</nav>'
        . '<div id="whm-right-content">' . $content . '</div>'
        . '</body></html>';
    return 1;
}

1;
