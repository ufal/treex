package Treex::Block::Write::LayerAttributes::LemmaFormDist;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Python::RunFunc;

use String::Diff;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => (
    builder    => '_build_return_values_names',
    lazy_build => 1
);

has 'output_diff' => (
    isa     => 'Bool',
    is      => 'ro',
    default => 0
);

has 'split_parts' => (
    isa => enum( [ 'no', 'front', 'all' ] ),
    is => 'ro',
    default => 'no'
);

has 'dist_func' => (
    isa => 'Str',
    is => 'ro',
    default => 'cstest' # other: levenshtein
);

has '_cache' => (
    is => 'rw',
    default => sub { {} },
);

has '_dist' => (
    is      => 'rw',
    builder => '_build_dist',
    lazy_build => 1
);

has 'mid_numbers' => (
    isa     => 'Bool',
    is      => 'ro',
    default => 0    
);

Readonly my $ESCAPE_SRC => [ '[',     ']',     '{',     '}' ];
Readonly my $ESCAPE_TGT => [ '-LBR-', '-RBR-', '-LBC-', '-RBC-' ];

# Build default return values' suffixes for different settings of
# output_diff and split_parts
sub _build_return_values_names {
    my ($self) = @_;
    my @retvals;

    if ( $self->split_parts eq 'no' ) {
        push @retvals, '';
    }
    elsif ( $self->split_parts eq 'front' ) {
        push @retvals, '_back', '_front';
    }
    else {
        push @retvals, '_back', '_mid', '_front';
    }
    if ( $self->output_diff ) {
        push @retvals, '_diff';
    }
    return \@retvals;
}

sub _build_dist {
    my ($self) = @_;

    my $dir = __FILE__;
    $dir =~ s/\/[^\/]*$//;
    
    my $dist = $self->dist_func;    

    my $python = Treex::Tool::Python::RunFunc->new();
    $python->command(
        "import os\n" .
            "os.chdir('$dir')\n" .
            "sys.path.append('.')\n" .
            "import string_distances\n" .
            "match = string_distances.match_$dist\n" .
            "gap = string_distances.gap_$dist\n"
    );
    return $python;
}

sub _get_diff {
    my ( $self, $s, $t ) = @_;
    return $self->_cache->{ $s . ' ' . $t } if ( defined( $self->_cache->{ $s . ' ' . $t } ) );
    $s =~ s/'/\\'/g;
    $t =~ s/'/\\'/g;
    my $diff = $self->_dist->command("print string_distances.merged_diff('$s','$t', match, gap)\n");
    $self->_cache->{ $s . ' ' . $t } = $diff;
    return $diff;
}

# Escape brackets before diffing
sub escape {
    my ($str) = @_;
    for ( my $i = 0; $i < @{$ESCAPE_SRC}; ++$i ) {
        my $src = $ESCAPE_SRC->[$i];
        my $tgt = $ESCAPE_TGT->[$i];
        $str =~ s/\Q$src\E/$tgt/g;
    }
    return $str;
}

# Unescape previously escaped brackets
sub unescape {
    my ($str) = @_;
    for ( my $i = 0; $i < @{$ESCAPE_SRC}; ++$i ) {
        my $src = $ESCAPE_SRC->[$i];
        my $tgt = $ESCAPE_TGT->[$i];
        $str =~ s/\Q$tgt\E/$src/g;
    }
    return $str;
}

sub modify_single {

    my ( $self, $lemma, $form ) = @_;

    return undef if ( !defined($lemma) || !defined($form) );

    $lemma = escape( lc $lemma );
    $form  = escape( lc $form );

    my $diff = $self->_get_diff( $lemma, $form );

    # fix: špatný -> horšímu, horšího
    # $diff =~ s/^<hor>š`([^']+)'</`š$1'<horš/;

    # find the changes in the diff
    my ( $front, $mid, $back ) = ( '', '', '' );

    # no change
    if ( $diff !~ m/[`'<>]/ ) {
        $back = '';
    }

    # everything changed
    elsif ( $diff =~ m/^`[^']*'/ ) {
        $back = '*' . $form;
    }

    # just something has changed
    else {

        # change at the end
        if ( $diff =~ m/(?:`([^']+)')?(?:<([^>]+)>)?$/ && ( $1 // $2 ) ) {
            my $len = length( $1 // '' );
            my $add = $2 // '';
            $back = '>' . $len . $add;
        }

        # changes in the middle
        while ( $diff =~ m/([^'`<>])(?:`([^']+)'|<([^>]+)>){1,2}(?=[^'`<>])/g && ( $2 // $3 ) ) {
            my $orig = $2 // '';
            my $new  = $3 // '';
            if ( !$self->mid_numbers ){
                if ( !defined($2) ) {
                    $orig = $1;
                    $new  = $1 . $3;
                }
            }
            else {
                my $tail = substr( $diff, pos $diff );
                $tail =~ s/([`']|<[^>]*>)//g;
                my $posnum = length($tail) + length($orig);
                $orig = $posnum . ':' . length($orig);
            }
            $mid = !$mid ? ( $orig . '-' . $new ) : ( $orig . '-' . $new . ' ' . $mid );
        }

        # something added to the beginning
        if ( $diff =~ m/^<([^>]*)>/ ) {
            $front = '<' . $1;
        }
    }

    # prepare return value(s)
    my @ret;
    if ( $self->split_parts eq 'no' ) {
        push @ret, join( ',', grep { $_ ne '' } $back, $mid, $front );
    }
    elsif ( $self->split_parts eq 'front' ) {
        push @ret, join( ',', grep { $_ ne '' } $back, $mid );
        push @ret, $front;
    }
    else {
        push @ret, $back, $mid, $front;
    }

    if ( $self->output_diff ) {
        push @ret, $diff;
    }
    return @ret;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::LemmaFormDist

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::LemmaFormDist->new();
        

=head1 DESCRIPTION

Given a lemma and one of its forms, return the differences between 
the lemma and the form (i.e. how to obtain the form from the lemma).

=head1 SETTINGS

TODO

=head1 NOTES

Some words had to be hard-set as irregular.

Only "legal" prefixes should be: nejne, ne, nej, po, pů

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, 
Charles University in Prague

This module is free software; you can redistribute it and/or modify it 
under the same terms as Perl itself.
