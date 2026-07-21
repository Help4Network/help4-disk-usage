package Cpanel::LiveAPI;

use strict;
use warnings;

sub new {
    return bless { ended => 0 }, shift;
}

sub header {
    my ($self, $title) = @_;
    $title ||= 'cPanel';
    return '<!doctype html><html><head><meta charset="utf-8"><title>' . $title
        . '</title></head><body><nav id="cpanel-main-navigation">Tools</nav>'
        . '<main id="cpanel-page-content">';
}

sub footer {
    return '</main><footer id="cpanel-shell-footer">cPanel</footer></body></html>';
}

sub end {
    my ($self) = @_;
    die "LiveAPI end called more than once\n" if $self->{ended};
    $self->{ended} = 1;
    return;
}

1;
