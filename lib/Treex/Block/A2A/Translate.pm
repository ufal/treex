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
    my ( $self, $zone ) = @_;

    my $sentence = $self->get_sentence_and_node_positions($zone);

    return $self->_translator->translate_align($sentence);
};

sub get_sentence_and_node_positions {
    my ($self, $zone) = @_;

    # precompute node positions
    my @nodes = $zone->get_atree()->get_root()->get_descendants(
        { ordered => 1 }
    );
    my $length        = 0;
    foreach my $node (@nodes) {

        # store position
        $self->position2node->{$length} = $node;

        # move on
        $length += length $node->form;
        if ( !$node->no_space_after ) {
            $length++;
        }
    }

    return $zone->sentence;
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
    my ( $self, $translation_result, $zone ) = @_;

    my $translation = $translation_result->{translation};
    if ( $self->SUPER::set_translation( $translation, $zone ) ) {

        # success
        # sentence has already been set in SUPER

        # store the translations
        my $last = '';
        my $trnode;
        my $trroot;
        if ( $self->save_to_tree ) {
            $trroot = $self->get_translation_tree($zone, 1);
            $trnode = $trroot;
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
                if ( $word ne $last ) {
                    # add node
                    my $lastnode = $trnode;
                    $trnode = $trroot->create_child({form => $word});
                    $trnode->shift_after_node($lastnode);
                }
                # add alignment
                $node->add_aligned_node($trnode, $self->alignment_type);
            }

            $last = $word;
        }

        return 1;
    }
    else {

        # failure
        # log_warn has already been called in SUPER
        return 0;
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

