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

    if (defined $formeme) {

        # defaults
        $splitFormeme->{formeme}  = $formeme;
        $splitFormeme->{syntpos}  = $formeme;
        $splitFormeme->{prep} = '';
        $splitFormeme->{case} = '';         # 1-7, X, attr, poss
    
        if ( $formeme =~ /^(.*):(.*)$/ ) {
            $splitFormeme->{syntpos}  = $1;
            $splitFormeme->{case} = $2;
            if ( $splitFormeme->{case} =~ /^([^\+]*)\+(.*)$/ ) {
                $splitFormeme->{prep} = $1;
                $splitFormeme->{case} = $2;
            }
        }
    
        my @preps = split /_/, $splitFormeme->{prep};
        $splitFormeme->{preps} = \@preps;
    }
    else {
        $splitFormeme->{formeme}  = '';
        $splitFormeme->{syntpos}  = '';
        $splitFormeme->{prep} = '';
        $splitFormeme->{case} = '';
        my @preps = ();
        $splitFormeme->{preps} = \@preps;
    }

    return $splitFormeme;
}

1;

=head1 NAME 

Treex::Tool::Depfix::CS::FormemeSplitter

=head1 DESCRIPTION

Splits the formeme into parts...
The same rules as in Treex::Block::Write::LayerAttributes::AttributeModifier,
but a little different return values and has some extra functionality.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
