package Treex::Block::Write::CoNLLU;

use strict;
use warnings;
use Moose;
use Lingua::Interset qw(encode);
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

my %FALLBACK_FOR = ( 'pos' => 'tag', 'deprel' => 'afun', );

has '+language'                        => ( required => 1 );
has 'deprel_attribute'                 => ( is       => 'rw', isa => 'Str', default => 'autodetect' );
has 'is_member_within_afun'            => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'is_shared_modifier_within_afun'   => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'is_coord_conjunction_within_afun' => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'randomly_select_sentences_ratio'  => ( is       => 'rw', isa => 'Num',  default => 1 );

has _was => ( is => 'rw', default => sub{{}} );

has '+extension' => ( default => '.conllu' );

sub process_atree
{
    my $self = shift;
    my $tree = shift;
    # if only random sentences are printed
    return if rand() > $self->randomly_select_sentences_ratio;
    foreach my $node ($tree->get_descendants({ ordered => 1 }))
    {
        my $ord = $node->ord();
        my $form = $node->form();
        my $lemma = $node->lemma();
        my $tag = $node->tag();
        my $isetfs = $node->iset();
        my $upos_features = encode('mul::uposf', $isetfs);
        my ($upos, $feat) = split(/\t/, $upos_features);
        my $pord = $node->get_parent()->ord();
        my $misc = $node->no_space_after() ? 'SpaceAfter=No' : '_';
        # 'conll/' will be prefixed if needed; see get_attribute().
        my $deprel = $self->get_attribute($node, 'deprel');
        # Append suffices to afuns.
        ###!!! We will want to remove this in future. The dependency labels we output will have to conform to the Universal Dependencies standard.
        my $suffix = '';
        $suffix .= 'M' if $self->is_member_within_afun            && $node->is_member;
        $suffix .= 'S' if $self->is_shared_modifier_within_afun   && $node->is_shared_modifier;
        $suffix .= 'C' if $self->is_coord_conjunction_within_afun && $node->wild->{is_coord_conjunction};
        $deprel .= "_$suffix" if $suffix;
        # CoNLL-U columns: ID, FORM, LEMMA, CPOSTAG=UPOS, POSTAG=corpus-specific, FEATS, HEAD, DEPREL, DEPS(additional), MISC
        # Make sure that values are not empty and that they do not contain spaces.
        my @values = ($ord, $form, $lemma, $upos, $tag, $feat, $pord, $deprel, '_', $misc);
        @values = map
        {
            my $x = $_ // '_';
            $x =~ s/^\s+//;
            $x =~ s/\s+$//;
            $x =~ s/\s+/_/g;
            $x = '_' if($x eq '');
            $x
        }
        (@values);
        print { $self->_file_handle() } join("\t", @values)."\n";
    }
    print { $self->_file_handle() } "\n" if($tree->get_descendants());
    return;
}



#------------------------------------------------------------------------------
# Maps Treex attributes to CoNLL-U columns. The mapping is parameterizable in
# some cases.
#------------------------------------------------------------------------------
sub get_attribute
{
    my $self = shift;
    my $node = shift;
    my $name = shift;
    my $from = $self->{ $name . '_attribute' } || $name;    # TODO don't expect blessed hashref
    my $value;
    if ($from eq 'autodetect')
    {
        my $before = $self->_was->{$name};
        if (!defined($before))
        {
            $value = $node->get_attr("conll/$name");
            if (defined($value))
            {
                $self->_was->{$name} = "conll/$name";
            }
            else
            {
                my $fallback = $FALLBACK_FOR{$name} or log_fatal("No fallback for attribute $name");
                $value = $node->get_attr($fallback);
                $self->_was->{$name} = $fallback;
            }
        }
        else
        {
            $value = $node->get_attr($before);
            if (!defined($value) && $before =~ /^conll/)
            {
                my $id = $node->get_address();
                log_warn("Attribute $before not defined in $id but non-empty values did appear previously. Consider Write::CoNLLU with the parameter ${name}_attribute != autodetect.");
            }
        }
    }
    else
    {
        $value = $node->get_attr($from);
    }
    return defined($value) ? $value : '_';
}

1;

__END__

=head1 NAME

Treex::Block::Write::CoNLLU

=head1 DESCRIPTION

Document writer for the CoNLL-U data format
(L<http://universaldependencies.github.io/docs/format.html>).

=head1 PARAMETERS

=over

=item encoding

Output encoding. C<utf8> by default.

=item to

The name of the output file, STDOUT by default.

=item deprel_attribute

The name of attribute which will be printed into the 8th column (dependency relation).
Default is C<autodetect> which tries first C<conll/deprel>
and if it is not defined then C<afun>.

=back

=head1 METHODS

=over

=item process_atree

Saves (prints) the CoNLL-U representation of one sentence (one dependency tree).

=back

=head1 AUTHOR

Daniel Zeman

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
