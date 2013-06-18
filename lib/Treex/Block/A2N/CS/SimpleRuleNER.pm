package Treex::Block::A2N::CS::SimpleRuleNER;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;

extends 'Treex::Core::Block';

Readonly my $LEMMA2TYPE => {

    'Y' => 'pf',    # given name (formerly used as default): Petr, John
    'S' => 'ps',    # surname, family name: Dvořák, Zelený, Agassi, Bush
    'E' => 'pc',    # member of a particular nation, inhabitant of a particular territory: Čech, Kolumbijec, Newyorčan
    'G' => 'g_',    # geographical name: Praha, Tatry (the mountains)
    'K' => 'i_',    # company, organization, institution: Tatra (the company)
    'R' => 'op',    # product: Tatra (the car)
    'm' => 'g_',    # other proper name: names of mines, stadiums, guerilla bases, etc.
    'H' => 'oc',    # chemistry
    'U' => 'o_',    # medicine
    'L' => 'o_',    # natural sciences
    'j' => 'o_',    # justice
    'g' => 'o_',    # technology in general
    'c' => 'o_',    # computers and electronics
    'y' => 'o_',    # hobby, leisure, travelling
    'b' => 'o_',    # economy, finances
    'u' => 'oa',    # culture, education, arts, other sciences
    'w' => 'o_',    # sports
    'p' => 'o_',    # politics, governement, military
    'z' => 'o_',    # ecology, environment
    'o' => '',      # color indication
};

sub process_zone {

    my ( $self, $zone ) = @_;

    my $aroot = $zone->get_atree();
    my @anodes = $aroot->get_descendants( { ordered => 1 } );

    # skip empty sentence
    return if !@anodes;

    # Create new n-tree
    my $n_root = $zone->has_ntree() ? $zone->get_ntree() : $zone->create_ntree();

    # Add all named entities found to the n-tree
    foreach my $i ( 0 .. $#anodes ) {
    
        # Skip words recognized by a potential previous NER classifier
        next if $anodes[$i]->n_node;

        my $form  = $anodes[$i]->form;
        my $lemma = $anodes[$i]->lemma;
        my $type  = '';

        # Take the term type from the lemma
        if ( $type = Treex::Tool::Lexicon::CS::get_term_types($lemma) ) {

            $type = 'Y' if ( $type =~ /Y/ );    # always prefer personal names or companies if multiple types are possible
            $type = 'S' if ( $type =~ /S/ );
            $type = 'K' if ( $type =~ /K/ );
            $type = substr( $type, 0, 1 );
            $type = $LEMMA2TYPE->{$type};
        }

        if ( !$type && _is_ucfirst($form) ) {

            # Surname rule
            if ( _prev_type( \@anodes, $i ) =~ /p[fmdc]/ ) {
                $type = 'ps';
            }

            # Other capitalized nouns or unrecognized words not following punctuation
            elsif ( !_after_term_punct( \@anodes, $i ) ) {
                my $tag = $anodes[$i]->tag;

                if ( $tag =~ m/^N.[MF]/ ) {    # animate/feminine are considered personal names
                    $type = 'p_';
                }
                elsif ( $tag =~ m/^(N.[IN]|X@)/ ) {    # other are considered institution names
                    $type = 'i_';
                }
            }
        }

        if ($type) {
            $lemma = Treex::Tool::Lexicon::CS::truncate_lemma( $lemma, 1 );
            $lemma = ucfirst $lemma if ( $type =~ /^p/ );
            
            my $n_node = $n_root->create_child(
                ne_type => $type,
                normalized_name => $lemma
            );
            $n_node->set_anodes( $anodes[$i] );
        }
    }
    return 1;
}

sub _prev_type {

    my ( $nodes, $cur ) = @_;
    my $type         = '';
    my $passed_punct = 0;

    $cur--;
    return '' if ( $cur < 0 );
    if ( $cur > 0 && $nodes->[$cur]->form =~ /\p{Punct}/ ) {
        $cur--;
        $passed_punct = 1;
    }
    $type = $nodes->[$cur]->n_node->ne_type if ( $nodes->[$cur]->n_node );
    $type =~ s/p[fmc]// if ($passed_punct);
    return $type;
}

sub _is_ucfirst {
    my ($form) = @_;

    return 0 if ( $form !~ m/^\p{Alpha}/ );
    return ( $form eq uc( substr( $form, 0, 1 ) ) . lc( substr( $form, 1 ) ) );
}

sub _after_term_punct {
    my ( $nodes, $cur ) = @_;

    return 1 if ( $cur == 0 );
    return $nodes->[ $cur - 1 ]->form =~ /[!.:?]/;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2N::CS::SimpleRuleNER

=head1 DESCRIPTION

A primitive named entity recognizer making use of Czech lemma structure and a simple rule (capitalized word
following a given name or an academic title is assumed to be a surname).

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
