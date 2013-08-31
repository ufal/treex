package Treex::Block::A2A::Translate;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::W2W::Translate';

has save_to_gloss => ( is => 'rw', isa => 'Bool', default => 1 );

has save_to_wild => ( is => 'rw', isa => 'Bool', default => 0 );

has wild_name => ( is => 'rw', isa => 'Str', default => 'gloss' );

has save_to_tree => ( is => 'rw', isa => 'Bool', default => 1 );

has alignment_type => ( is => 'rw', isa => 'Str', default => 'gloss' );

has position2node => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

has try_to_split => ( is => 'rw', isa => 'Bool', default => 1 );

has split_on_deprel => ( is => 'rw', isa => 'Str', default => 'AuxK' );
# AuxK|AuxC|Coord

has add_splitter_to_following => ( is => 'rw', isa => 'Bool', default => 0 );

override '_build_translator' => sub {
    my $self = shift;

    my $translator = super();
    $translator->set_align(1);

    return $translator;
};

override 'has_translation' => sub {
    my ( $self, $zone ) = @_;

    # sentence
    my $result1 = $self->old_translation($zone) ne '';
    # or gloss attributes
    my $result2 = $result1
    || ($self->save_to_gloss && any {
            defined $_->gloss && $_->gloss ne ''
        } $zone->get_atree()->get_root()->get_descendants());
    # or wild attributes
    my $id = $self->target_language . '_' . $self->target_selector;
    my $result3 = $result2
    || ($self->save_to_wild && any {
            defined $_->wild->{ $self->wild_name }->{$id}
            && $_->wild->{ $self->wild_name }->{$id} ne ''
        } $zone->get_atree()->get_root()->get_descendants());
    # or tree
    my $result = $result3
    || ($self->save_to_tree && defined $self->get_translation_tree($zone));

    return $result;
};

sub get_translation_tree {
    my ($self, $zone, $createIfNotExists) = @_;

    my $root = undef;
    my $bundle = $zone->get_bundle();
    if ( $bundle->has_tree(
            $self->target_language, 'a', $self->target_selector)
    ) {
        $root = $bundle->get_tree(
            $self->target_language, 'a', $self->target_selector);
    }
    elsif ( $createIfNotExists ) {
        $root = $bundle->create_tree(
            $self->target_language, 'a', $self->target_selector);
    }

    return $root;
}

override 'get_translation' => sub {
    my ( $self, $zone, $nodes ) = @_;

    if ( !defined $nodes ) {
        my @all_nodes = $zone->get_atree()->get_root()->get_descendants(
            { ordered => 1 }
        );
        $nodes = \@all_nodes;
    }
    my $sentence = $self->get_sentence_and_node_positions($nodes);

    return $self->_translator->translate_align($sentence);
};

sub get_sentence_and_node_positions {
    my ($self, $nodes) = @_;

    # precompute node positions
    $self->set_position2node({});
    my $sentence = '';
    my $position = 0;
    foreach my $node (@$nodes) {

        # form and its length
        my $form = $node->no_space_after ? $node->form : $node->form . ' ';
        my $formlen = length $form;

        # store position
        $self->position2node->{$position} = $node;

        # move on
        $sentence .= $form;
        $position += $formlen;
    }

    return $sentence;
}

override 'delete_translation' => sub {
    my ( $self, $zone ) = @_;

    super();
    
    my @nodes = $zone->get_atree()->get_root()->get_descendants();
    foreach my $node (@nodes) {
        if ( $self->save_to_gloss ) {
            $node->set_gloss( '' );
        }
        if ( $self->save_to_wild ) {
            my $id = $self->target_language . '_' . $self->target_selector;
            $node->wild->{ $self->wild_name }->{$id} = '';
        }
    }
    if ( $self->save_to_tree ) {
        if ( defined $self->get_translation_tree($zone) ) {
            $zone->get_bundle->get_zone(
                $self->target_language, $self->target_selector
            )->remove_tree('a');
        }
    }

    return;
};

override 'set_translation' => sub {
    my ( $self, $translation_result, $zone, $nolog ) = @_;

    my $translation = $translation_result->{translation};
    if ( $self->SUPER::set_translation( $translation, $zone, $nolog ) ) {

        # success
        # sentence has already been set in SUPER

        # store the translations
        my $last = undef;
        my $trnode = undef;
        my $trroot;
        if ( $self->save_to_tree ) {
            $trroot = $self->get_translation_tree($zone, 1);
        }
        foreach my $aligninfo ( @{ $translation_result->{align} } ) {

            my $word     = $aligninfo->{word};
            my $position = $aligninfo->{position};

            # normalize position;
            # should not be needed, but should not die on this either...
            my $node = $self->position2node->{$position};
            while ( !defined $node ) {
                log_warn "Position $position for '$word' not matched, have to adjust...";
                $position--;
                $node = $self->position2node->{$position};
            }

            # set the translation
            $self->set_node_translation($node, $word);
            if ( $self->save_to_tree ) {
                if ( !defined $trnode ) {
                    # add the first trnode
                    $trnode = $trroot->create_child({form => $word});
                    $trnode->shift_after_node($trroot);
                }
                elsif ( $word ne $last ) {
                    # add next node
                    my $lastnode = $trnode;
                    $trnode = $trroot->create_child({form => $word});
                    $trnode->shift_after_node($lastnode);
                }
                # add alignment
                $trnode->add_aligned_node($node, $self->alignment_type);
            }

            $last = $word;
        }

        return 1;
    }
    else {

        # failure
        # log_warn has already been called in SUPER
        if ( $self->try_to_split ) {
            log_info 'Will try to split the sentence on '
                . $self->split_on_deprel;
            return $self->split_translation($zone);
        }
        else {
            return 0;
        }
    }

};

sub set_node_translation {
    my ($self, $node, $translation) = @_;

    if ( $self->save_to_gloss ) {
        $node->set_gloss( $self->concatenate($node->gloss, $translation) );
    }

    if ( $self->save_to_wild ) {
        my $id = $self->target_language . '_' . $self->target_selector;
        $node->wild->{ $self->wild_name }->{$id} = $self->concatenate(
            $node->wild->{ $self->wild_name }->{$id}, $translation );
    }

    return;
}

sub split_translation {
    my ($self, $zone) = @_;

    my $result = 1;
    my @allNodes = $zone->get_atree()->get_root()->get_descendants(
        { ordered => 1 }
    );
    my @splitterOrds =
        map { $_->ord }
            (grep { $_->conll_deprel =~ $self->split_on_deprel } @allNodes);
    if ( @splitterOrds == 0) {
        log_warn "No splitters found!";
        return 0;
    }
    if ( $splitterOrds[-1] == @allNodes ) {
        pop @splitterOrds;
    }
    if ( @splitterOrds == 0) {
        log_warn "No splitters found!";
        return 0;
    }
    log_info "Split [1, " . scalar(@allNodes) . "] " .
        "on {" . (join ', ', @splitterOrds) . "}";
    # add exclusive upper bound
    push @splitterOrds, (scalar(@allNodes)+1); # == $allNodes[-1]->ord + 1
    my $from = 0;
    foreach my $to (@splitterOrds) {
        if ( $self->add_splitter_to_following ) {
            $to--;
        }
        my @nodesSlice =
            grep { $_->ord > $from && $_->ord <= $to } @allNodes;
        my $translation = $self->get_translation( $zone, \@nodesSlice );        
        if ( $translation->{translation} ne '' ) {
            log_info "Translated ($from,$to] " .
                $self->language . ":'" .
                ( join ' ', (map { $_->form } @nodesSlice) ) .  "'" .
                " to " . $self->target_language . ":'" .
                $translation->{translation} . "'";
            $self->set_translation( $translation, $zone, 'nolog' );
        }
        else {
            log_warn "($from,$to]: No translation generated - no translation saved!";
            $result = 0;
        }
        $from = $to;
    }

    return $result;
}


1;

=head1 NAME 

Treex::Block::A2A::Translate

Translates the sentence, including individual a-nodes, using Google Translate.

=head1 DESCRIPTION

Not only sets the full sentence as L<Treex::Block::W2W::Translate>, but also
sets translations of individual a-nodes, using the alignment provided by Google
Translate.

The translations are stored into the C<gloss> attributes of the nodes.
They also can be stored into wild attributes of the nodes - by default into
C<node-&gt;wild-&gt;{gloss}-&gt;{language_selector}>,
e.g. C<node-&gt;wild-&gt;{gloss}-&gt;{en_GT}> if default C<wild_name>,
C<target_language>
and C<target_selector> are used.
This is useful if translating into several target languages, as the C<gloss>
attribute can easily hold one translation only.

If the sentence is too long and if C<try_to_split> is true (which is the default),
will try to split the sentence on C<split_on_deprel> conll deprels (the default
is C<AuxK>, i.e. end-of-sentence punctuation, but any regex can be used),
translate each of the resulting chunks separately, and concatenate the resulting
translations into one sentence translation (the alignment is also handled
correctly).
The splitter will be added to the preceding chunk by default, or to the
following chunk if C<add_splitter_to_following> is set to C<1>.

Otherwise is similar to L<Treex::Block::W2W::Translate>.

Uses L<Treex::Tool::GoogleTranslate::APIv1>.

=head1 SYNOPSIS
 
 # translate all Bulgarian sentences in the file to English, into en_GT zone,
 # storing the translation of each individual node into $node->gloss
 treex -s A2A::Translate language=bg -- bg_file.treex.gz

 # translate to Czech, store also to $node->wild->{gloss}->{cs_GOOGLE}
 treex -s A2A::Translate language=bg save_to_wild=1 target_language=cs target_selector=GOOGLE -- bg_file.treex.gz

 # translate only first 5 sentences
 treex -s A2A::Translate language=bg sid='s1 s2 s3 s4 s5' -- bg_file.treex.gz

=head1 PARAMETERS

=over

=item save_to_gloss

C<1> to store the translation into the C<gloss> attributes of a-nodes. Default is C<1>.

=item save_to_wild

C<1> to store the translation into wild attributes of a-nodes. Default is C<0>.

=item wild_name

The name of the wild attribute to store the translations in on a-nodes.
The default is C<gloss>.

=item save_to_tree

C<1> to store the translation into a flat tree. The nodes of the source tree will be
aligned to nodes of the translation tree, with the alignment type equal to
C<alignment_type>.

Default is C<1>.

=item alignment_type

The type to set for alignment links to translation tree if C<save_to_tree>.
Default is C<gloss>.

=item language

Source language. Required.

=item target_language

Defaults to C<en>.

=item target_selector

Defaults to C<GT>.

=item sid

List of sentence ids to translate, separated by spaces.
If set, only the sentences with the given ids will be translated.
Defaults to C<undef> - all sentences are translated by default.

=item auth_token

Your AUTH_TOKEN from Google.
If not set, it will be attempted to read it from
C<auth_token_in_file>.
If this is not successful, a C<log_fatal> will be issued.

If you have registered for the University Research
Program for Google Translate, you can get one using your email,
password and the
following procedure (copied from official manual):

Here is an example using curl to get an authentication token:

  curl -d "Email=username@domain&Passwd=password&service=rs2"
  https://www.google.com/accounts/ClientLogin

Make sure you remember to substitute in your username@domain and
password. Also, be warned that your username and password may be
stored in your history file (e.g., .bash_history) and you should
take precautions to remove it when finished. 

=item auth_token_in_file

File containing the C<auth_token>.
Defaults to C<~/.gta> (cross-platform solution is used, i.e. C<~> is
the user
home directory as returned by L<File::HomeDir>).

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

