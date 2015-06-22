#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Storable qw(store);

my %genders;

binmode( STDIN, ':utf8' );

while ( my $line = <> ) {
    chomp $line;
    my ( $form, $lemma, $pos ) = split /\t/, $line;
    next if ( $pos !~ /^noun/ );
    $lemma =~ s/^'//;
    $lemma =~ s/'$//;
    $lemma =~ s/\\'/'/g;

    my $gender = '';
    $gender = 'neut' if ( $pos =~ /\(het,/ );
    $gender = 'com'  if ( $pos =~ /\(de,/ );
    $gender = 'both'  if ( $pos =~ /\(both,/ );
    
    if (!$gender){
        print STDERR 'No gender found: ' . $line . "\n";
        next;
    }
    $genders{$lemma} = $gender;
}

# overrides
$genders{'venster'} = 'neut';
$genders{'router'} = 'com';

store \%genders, 'genders.pls';

__END__

=encoding utf-8

=head1 NAME

alpino_extract_gender.pl

=head1 DESCRIPTION

Extracting genders from the Alpino dictionary (C<Alpino/Lexicon/lex.t>),
with a few manual overrides. 

The extracted list of genders is stored in Perl Storable file, as required 
by L<Treex::Block::T2T::EN2NL::AddNounGender>.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
