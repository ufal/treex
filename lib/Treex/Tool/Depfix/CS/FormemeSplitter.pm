package Treex::Tool::Depfix::CS::FormemeSplitter;
use Moose;
use Treex::Core::Common;
use utf8;

# returns ($syntpos, \@preps, $case)
sub splitFormeme {
    my ($formeme) = @_;
    
    my $splitFormeme = analyzeFormeme($formeme);
    
    return ( $splitFormeme->{syntpos}, $splitFormeme->{preps}, $splitFormeme->{case} );
}

sub analyzeFormeme {
    my ($formeme) = @_;

    my $splitFormeme = {};

    # n:
    # n:2
    # n:attr
    # n:v+6

    # defaults
    $splitFormeme->{formeme}  = $formeme;
    $splitFormeme->{syntpos}  = $formeme;
    $splitFormeme->{prep} = '';
    $splitFormeme->{case} = '';         # 1-7, X, attr, poss

    if ( $formeme =~ /^([a-z]+):(.*)$/ ) {
        $splitFormeme->{syntpos}  = $1;
        $splitFormeme->{case} = $2;
        if ( $splitFormeme->{case} =~ /^(.*)\+(.*)$/ ) {
            $splitFormeme->{prep} = $1;
            $splitFormeme->{case} = $2;
        }
    }

    my @preps = split /_/, $splitFormeme->{prep};
    $splitFormeme->{preps} = \@preps;

    return $splitFormeme;
}

1;

=head1 NAME 

Treex::Tool::Depfix::CS::FormemeSplitter

=head1 DESCRIPTION

Splits the formeme into parts...

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
