#!/usr/bin/env perl
use Moose;
use Treex::Core::Common;

use Morce::English;
#use DowngradeUTF8forISO2;

print STDERR "Starting tagger...\n";

my $tagger = Morce::English->new();
my $formFieldIndex = 1;
my $tagFieldIndex = 3;
my $ctagFieldIndex = 4;

print STDERR "Tagging the sentences...\n";

my @lines;
my @forms;
open my $file, '<:utf8', $ARGV[0] or die 'cannot open input file';
while (<$file>) {
    chomp;
    if (/^$/) {
        my ($tags_rf) = $tagger->tag_sentence( \@forms );
        foreach my $line (@lines) {
	    my $tag = shift @{$tags_rf};
            $line->[$tagFieldIndex] = $tag;
            $line->[$ctagFieldIndex] = get_coarse_grained_tag($tag);
            print join "\t", @$line;
            print "\n";
        }
        print "\n";
        undef @lines;
        undef @forms;
    } else {
        my @fields = split /\t/;
        push @lines, \@fields;
        #push @forms, DowngradeUTF8forISO2::downgrade_utf8_for_iso2($fields[$form
        push @forms, $fields[$formFieldIndex];
    }
}

if (@lines) {
    my ($tags_rf) = $tagger->tag_sentence( \@forms );
    foreach my $line (@lines) {
	my $tag = shift @{$tags_rf};
	$line->[$tagFieldIndex] = $tag;
	$line->[$ctagFieldIndex] = get_coarse_grained_tag($tag);
	print join "\t", @$line;
	print "\n";
    }
}
close $file;
print STDERR "Done.\n";

sub get_coarse_grained_tag {
    my $tag = shift;
    my $ctag = substr( $tag, 0, 2 );
    return $ctag;
}
