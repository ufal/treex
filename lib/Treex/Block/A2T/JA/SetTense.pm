package Treex::Block::A2T::JA::SetTense;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# right now we only distinguish polite and basic politeness (PDT style)
my %aux2flags = (
  'ます'    => ['pol'],   # polite imperfective
  'た'      => ['perf'],  # plain perfective
  'ない'    => ['neg'],   # plain negative imperfective
  'ん'      => ['neg'],   # negative
  'たら'    => ['past', 'cdn'],  # past conditional
  'う'      => [],        # volitional, presumptive, hortative
  'れる'    => ['pass'],  # passive
  'られる'  => ['pass'],  # passive (or potential)
  'せる'    => [],        # causative (letting or making someone do something)
  'させる'  => [],        # causative (letting or making someone do something)
  'ば'      => ['cdn'],   # conditional
  'て'      => [],        # gerundive (te-form)
  'な'      => ['neg'],   # prohibitive
  'たい'    => [],        # volitional (wishing)
  # interrogative
);

# We mark the value of deontmod into the hash
# SetGrammateme will be the one to set the deontmod grammateme  
my %aux2deontmod = (
  'う'      => 'hrt',     # volitional, presumptive, hortative
  'せる'    => 'perm',    # causative (letting or making someone do something)
  'させる'  => 'perm',    # causative (letting or making someone do something)
  'たい'    => 'vol',     # volitional (wishing)
);

sub process_tnode {
  my ($self, $tnode) = @_;
  my $lex_anode = $tnode->get_lex_anode();

  # analyze verbs
  # TODO: how should we handle adjectives, copulas?
  if ( defined $lex_anode && ( $lex_anode->tag =~ /^(Dōshi)/ || $lex_anode->lemma =~ /^(です|だ)/ ) ) {
    
    my @anodes = $self->get_anodes($tnode);
    my @flags = ();
    my %tense = ();

    # 1. collect flags & set deontmod value in the tense hash
    foreach my $aux (@anodes) {
      my $flag_ref = $aux2flags{$aux->lemma};
      if ( $flag_ref ) {
        push @flags, @$flag_ref;
      }

      $tense{'deontmod'} = $aux2deontmod{$aux->lemma};

    }

    # 2. if flag "past" is not set, we assume present tense (which we take as a default for Japanese non-past tense)
    if ( scalar @flags > 0 && !( any { $_ eq 'past' } @flags ) ) {
      push @flags, 'pres';
    }

    # 3. fill the tense hash
    foreach my $flag (@flags) {
      $tense{$flag} = 1;
    }

    # 5. set the tense of the t-node
    $tnode->wild->{tense} = \%tense;

    # TODO: copula (probably just politeness)

    # TODO: imperative from verb stem

  }

  return;
};

sub get_anodes {
  my ($self, $tnode) = @_;
  my @anodes = ();

  # copulas should have their own t-node
  push @anodes, grep { $_->tag =~ /^Jodōshi/ } $tnode->get_anodes( { ordered => 1} );

  # we want to use some conjunctive particles (e.g. "te"(て) and "ba"(ば))
  push @anodes, grep { $_->tag =~ /^Joshi/ && $_->lemma =~ /^(て|ば|な)/ } $tnode->get_anodes( { ordered => 1} );

  # TODO: consider particles too? (possible infinitives, e.g. "TABE NI iku" - go (somewhere) TO EAT)

  return @anodes;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::JA::SetTense - detect the Japanese tense

=head1 DESCRIPTION

Creates a C<wild-&gt;{tense}> hash reference for each verb.
The hash contains flags, such as pres, perf, cdn, vol...
Negation is also included.
All of the flags are binary - either the flag is present (and has the value of C<1>),
or it is not present (which is the "default").

=over

=item past, pres

If C<past> is not set, C<pres> is the default.

=item perf

=item cont

=item pass

=item cdn

=item neg

=back

Based on L<Treex::Block::A2T::EN::SetTense>.

=head1 FUTURE WORK

=item auxiliaries

Do not use only pure auxiliaries, but also auxiliaries, which have their own t-nodes at the moment.

=item copula and adjectives

Resolve copula, adjectives (form with or without copula).

=item imperative

In the used tokenization, imperative cannot be detected from auxiliary nodes, but we can probably
detect it from the verb stem.

=head1 AUTHORS

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012-2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
