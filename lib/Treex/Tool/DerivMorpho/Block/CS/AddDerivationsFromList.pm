package Treex::Tool::DerivMorpho::Block::CS::AddDerivationsFromList;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

has file => (
    is            => 'ro',
    isa           => 'Str',
    documentation => q(file name to load),
);

has maxlimit => (
    is => 'ro',
    isa => 'Int',
    documentation => q(maximum number of lexemes to create),
);

use Treex::Tool::Lexicon::CS;

sub process_dictionary {
    my ($self,$dict) = @_;

    open my $LIST, '<:utf8', $self->file or log_fatal $!;

    my $line;
    while (<$LIST>) {
        $line++;
        last if defined $self->maxlimit and $line > $self->maxlimit;
        next if /&amp;/;

	chomp;
	my ($source_short_lemma,$source_pos,$target_short_lemma,$target_pos) = split;

	my ($source_lexeme) = grep {$_->pos eq $source_pos} $dict->get_lexemes_by_lemma($source_short_lemma);
	my ($target_lexeme) = grep {$_->pos eq $target_pos} $dict->get_lexemes_by_lemma($target_short_lemma);

	if (not $source_lexeme) {
	  print  "ERR: No lexeme found for $source_short_lemma $source_pos\n";
	}
	elsif (not $target_lexeme) {
	  print "ERR: No lexeme found for $target_short_lemma $target_pos\n";
	}
	else {
	  print "OK: adding $source_short_lemma -> $target_short_lemma  \n";
	  $dict->add_derivation({
				 source_lexeme => $source_lexeme,
				 derived_lexeme => $target_lexeme,
				 deriv_type => $source_lexeme->pos."2".$target_lexeme->pos,
				 derivation_creator => $self->signature,
				}
			       );
	};
    }

    return $dict;
}

1;
