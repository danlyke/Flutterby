#!/usr/bin/perl -w
use strict;
package Flutterby::Tree::Find;


sub findClassArrayRecurse($$$)
{
    my ($tree, $tag,$r) = @_;
    my ($start);
    $start = 0;
    $start++ if (ref($tree->[0]));

    for (; $start < $#$tree; $start += 2) {
        if ($tree->[$start] ne '0') {
            if (defined($tree->[$start + 1]->[0]->{'class'})
                && " $tree->[$start + 1]->[0]->{'class'} " =~ /\s$tag\s/xs) {
                push @$r, [$tree->[$start], $tree->[$start + 1]];
            } else {
                &findClassArrayRecurse($tree->[$start + 1],$tag,$r);
            }
        }
    }
}

sub findClassFirstRecurse($$)
{
    my ($tree, $tag) = @_;
    my ($start);
    $start = 0;
    $start++ if (ref($tree->[0]));

    for (; $start < $#$tree; $start += 2) {
        if ($tree->[$start] ne '0') {
            if (defined($tree->[$start + 1]->[0]->{'class'})
                && " $tree->[$start + 1]->[0]->{'class'} " =~ /\s$tag\s/xs) {
                return [$tree->[$start], $tree->[$start + 1]];
            } else {
                my ($r);
                $r = &findClassFirstRecurse($tree->[$start + 1],$tag,$r);
                return $r if defined($r);
            }
        }
    }
    return undef;
}

sub class($$)
{
    my ($tree, $tag) = @_;
    $tag =~ s/(\W)/\\$1/xsg;

    if (wantarray) {
        my ($r);
        $r = [];
        findClassArrayRecurse($tree,$tag,$r);
        return @$r;
    } else {
        return findClassFirstRecurse($tree, $tag);
    }
}

sub findNodeArrayRecurse($$$)
{
    my ($tree, $tag,$r) = @_;
    my ($start);
    $start = 0;
    $start++ if (ref($tree->[0]));

    for (; $start < $#$tree; $start += 2) {
        if ($tree->[$start] ne '0') {
            if ($tree->[$start] eq $tag) {
                push @$r, [$tree->[$start], $tree->[$start + 1]];
            } else {
                &findNodeArrayRecurse($tree->[$start + 1],$tag,$r);
            }
        }
    }
}

sub findNodeFirstRecurse($$)
{
    my ($tree, $tag) = @_;
    my ($start);
    $start = 0;
    $start++ if (ref($tree->[0]));

    for (; $start < $#$tree; $start += 2) {
        if ($tree->[$start] ne '0') {
            if ($tree->[$start] eq $tag) {
                return [$tree->[$start], $tree->[$start + 1]];
            } else {
                my ($r);
                $r = &findNodeFirstRecurse($tree->[$start + 1],$tag,$r);
                return $r if defined($r);
            }
        }
    }
    return undef;
}

sub node($$)
{
    my ($tree, $tag) = @_;


    if (wantarray) {
        my ($r);
        $r = [];
        findNodeArrayRecurse($tree,$tag,$r);
        return @$r;
    } else {
        return findNodeFirstRecurse($tree, $tag);
    }
}


sub nodeChildInfo($$@)
{
    my ($tree, $tag, $start) = @_;
    my ($r);

    if (!defined($start)) {
        $start = 0;
        $start++ if (ref($tree->[0]));
    }

    for (; $start < $#$tree; $start += 2) {
        if ($tag eq $tree->[$start]) {
            $r = $tree->[$start + 1];
        } elsif ($tree->[$start] ne '0') {
            $r = &nodeChildInfo($tree->[$start + 1],$tag, 1);
        }
        return $r if ($r);
    }
    return undef;
}


sub allNodes($$@)
{
    my ($tree, $tag, $start,$ret) = @_;
    $ret = [] unless defined($ret);
    $start = 0 unless defined($start);

    for (; $start < $#$tree; $start += 2) {
        if ($tag eq $tree->[$start]) {
            push @$ret, $tree->[$start + 1];
        } elsif ($tree->[$start] ne '0') {
            &allNodes($tree->[$start + 1],$tag, 1,$ret);
        }
    }
    return $ret;
}
1;
