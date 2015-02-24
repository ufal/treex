package Treex::Block::T2A::NL::Alpino::FixMWUs;

use Moose;
use Treex::Core::Common;
use Storable qw(retrieve);

extends 'Treex::Core::Block';
with 'Treex::Block::T2A::NL::Alpino::MWUs';

has '_mwus' => ( is => 'ro', isa => 'HashRef', builder => '_build_mwus', lazy_build => 1 );

has 'mwu_file' => ( is => 'ro', isa => 'Str', default => 'data/models/lexicon/nl/mwus.pls' );

sub _build_mwus {
    my ($self)     = @_;
    my ($mwu_file) = $self->require_files_from_share( $self->mwu_file );
    return retrieve($mwu_file);
}

my %MWU_POS_MAPPING = (
    'adjective'   => 'adj',
    'preposition' => 'prep',
    'pre_num_adv' => 'det',
    'fixed_part'  => 'fixed',
);

sub process_anode {
    my ( $self, $anode ) = @_;

    # skip things that have already been recognized as MWUs
    return if ( ( $anode->wild->{adt_term_rel} // '' ) eq 'mwp' );

    # look if the current lemma matches some MWUs in the dictionary
    if ( my $mwu_cands = $self->_mwus->{ $anode->lemma } ) {

        # try to find the rest of the MWU for each matching one
        foreach my $mwu_cand (@$mwu_cands) {
            my ( $mwu_cand_str, $mwu_pos ) = split /\|/, $mwu_cand;

            # skip some types of MWUs that are apparently not needed
            next if ( $mwu_pos =~ /^(with_dt|conj|complementizer)$/ );
            $mwu_pos = $MWU_POS_MAPPING{$mwu_pos} // $mwu_pos;

            # try to find the rest of the MWU
            my $anodes = $self->detect_mwu( $mwu_cand_str, $anode );
            if ($anodes) {

                # create the MWU structure if we are successful
                log_info( 'Detected MWU: ' . $mwu_cand_str . ' ' . $mwu_pos . ' ' . join( ' ', map { $_->id } @$anodes ) );
                my $amwu_root = $self->create_mwu(@$anodes);

                # and set POS for all members
                map { $_->wild->{adt_pos} = $mwu_pos } @$anodes;
                $amwu_root->wild->{adt_pos} = $mwu_pos;
                last;
            }
        }
    }
    return;
}

sub detect_mwu {
    my ( $self, $cand_str, $anode ) = @_;

    my %cand_lemmas = ();
    my @cand_lemmas_arr = split / /, $cand_str;
    map { $cand_lemmas{$_} = ( $cand_lemmas{$_} // 0 ) + 1 } @cand_lemmas_arr;
    my $cand_len     = scalar( @cand_lemmas_arr );
    my @anodes       = ($anode);
    my %found_lemmas = ();
    my @afound       = ();

    # try to find all lemmas (with the specified number of occurrences) within the subtree
    while (@anodes) {
        my $acur = shift @anodes;
        next if ( !defined( $acur->lemma ) );

        # TODO allow backoff to multiple occurrences of the same lemma
        if ( $cand_lemmas{ $acur->lemma } and ( ( $found_lemmas{ $acur->lemma } // 0 ) < $cand_lemmas{ $acur->lemma } ) ) {
            $found_lemmas{ $acur->lemma } = ( $found_lemmas{ $acur->lemma } // 0 ) + 1;
            push @afound, $acur;
            push @anodes, $acur->get_children();
        }
    }

    # check if they are right after one another, check if they are in the same order as the candidate
    if ( scalar(@afound) == $cand_len ) {
        @afound = sort { $a->ord <=> $b->ord } @afound;        
        for ( my $i = 0; $i < @afound - 1; ++$i ) {
            return if ( $afound[$i]->ord + 1 != $afound[ $i + 1 ]->ord );
            return if ( $afound[$i]->lemma ne $cand_lemmas_arr[$i] );
        }
        return \@afound;
    }

    # return \@afound if ( scalar(@afound) == $cand_len );
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::Alpino::FixMWUs

=head1 DESCRIPTION


=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

    
