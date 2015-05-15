package Treex::Block::W2A::JA::TagMeCab;

use strict;
use warnings;

use Moose;
use Encode;
use Treex::Core::Common;
use Treex::Tool::Tagger::MeCab;

use Lingua::Interset::Tagset::JA::Ipadic;

extends 'Treex::Core::Block';

has _form_corrections => (
    is      => 'ro',
    isa     => 'HashRef[Str]',
    default => sub {
        {
            q(``) => q("),
            q('') => q("),
        }
    },
    documentation => q{Possible changes in forms done by tagger},
);

has tagger => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;

    return;
}

sub process_start {
    my ($self) = @_;

    my $tagger = Treex::Tool::Tagger::MeCab->new(); 
    $self->set_tagger( $tagger );
    
    return;   
} 

sub process_zone {


    my ( $self, $zone ) = @_;

    # get the source sentence
    my $sentence = $zone->sentence;
    log_fatal("No sentence in zone") if !defined $sentence;
    log_fatal(qq{There's already atree in zone}) if $zone->has_atree();
    log_debug("Processing sentence: $sentence"); 

    my ( @tokens ) = $self->tagger->process_sentence( $sentence );


	# create a-tree
	my $a_root = $zone->create_atree();
	my $ord = 1;

    # modify output of MeCab and create a-node for each sentence token
    foreach my $token ( @tokens ) {
    	my @features = split /\t/, $token;

        my $wordform = $features[0];
        my $tag = $features[1].'-'.$features[2].'-'.$features[3].'-'.$features[4];
        my $lemma = $features[7];      
		$lemma = $wordform if $lemma =~ m/\*/;

		# handle "special" tokens that MeCab produces sometimes
    	next if ($tag =~ /BOS/ || $tag =~ "空白");

		# create a-node
		if ( $sentence =~ s/^\Q$wordform\E// ) {
				my $space_start = qr{^\s+};
	
				# check if there is space after word
                my $no_space_after = $sentence =~ m/$space_start/ ? 0 : 1;
                if ( $sentence eq q{} ) {
                    $no_space_after = 0;
                }

                # delete it
                $sentence =~ s/$space_start//;

				log_debug("Creating a-node for: $wordform");

                # and create node under root
                my $a_node = $a_root->create_child(
                    form           => $wordform,
                    tag            => $tag,
                    lemma          => $lemma,
                    no_space_after => $no_space_after,
                    ord            => $ord++,
                );

                $tag =~ s/\-\*//g;

                # we also create an interset structure attribute
                my $driver = Lingua::Interset::Tagset::JA::Ipadic->new();
                my $features = $driver->decode("$tag");
                $a_node->set_iset($features);
		}	
		else {
        	log_fatal("Mismatch between tagged word and original sentence: Tagged word: \"$wordform\" Sentence: \"$sentence\"");
        }

    }

    return 1;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::TagMeCab

=head1 DESCRIPTION

Each sentence is tokenized and tagged using C<MeCab> (Ipadic POS tags).

Ipadic tagset uses hierarchical tags. There are four levels of hierarchy,
each level is separated by "-".
Empty categories are marked as "*".
Tags are in kanji, in the future they should be replaced by Romanized tags or their abbreviations (other japanese treex modules should be modified accordingly).

Interset feature structure for each node is also filled in this block.

=head1 SEE ALSO

L<MeCab Home Page|http://mecab.googlecode.com/svn/trunk/mecab/doc/index.html>

=head1 AUTHORS

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
