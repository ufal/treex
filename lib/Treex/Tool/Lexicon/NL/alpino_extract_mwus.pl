#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Storable qw(store);

my %mwu_words;

binmode( STDIN, ':utf8' );

while ( my $line = <> ) {
    chomp $line;
    my ( $form, $lemma, $pos ) = split /\t/, $line;
    next if ( $lemma !~ / / );
    $lemma =~ s/^'//;
    $lemma =~ s/'$//;
    $lemma =~ s/\\'/'/g;
    $pos =~ s/\(.*//;

    my $mwu = $lemma . '|' . $pos;
    my @words = split / /, $lemma;

    foreach my $word (@words) {
        if ( !defined( $mwu_words{$word} ) ) {
            $mwu_words{$word} = [];
        }
        if ( !grep { $_ eq $mwu } @{ $mwu_words{$word} } ) {
            push @{ $mwu_words{$word} }, $mwu;
        }
    }
}

store \%mwu_words, 'mwus.pls';

__END__

=encoding utf-8

=head1 NAME

alpino_extract_mwus.pl

=head1 DESCRIPTION

Multi-word unit types are extracted from the Alpino lexicon (C<Alpino/Lexicon/lex.t>)
and stored in a Perl Storable file as required by L<Treex::Block::T2A::NL::Alpino::FixMWUs>.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
