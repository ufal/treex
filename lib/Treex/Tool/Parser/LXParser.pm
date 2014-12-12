package Treex::Tool::Parser::LXParser;
use Moose;
use Treex::Core::Log;

extends 'Treex::Tool::LXSuite::Client';
with 'Treex::Tool::Parser::Role';

has 'lxsuite_mode' => (
    isa => 'Str', is => 'ro',
    default => 'conll.pos:parser:conll.lx'
);

sub parse_sentence {
    my ( $self, $forms, $lemmas, $cpostags, $postags, $feats ) = @_;

    my $cnt = scalar @$forms;
    $self->write();
    $self->write();
    for ( my $i = 0; $i < $cnt; $i++ ) {
        $self->write(($i+1) . "\t$$forms[$i]\t$$lemmas[$i]\t$$cpostags[$i]\t$$postags[$i]\t$$feats[$i]\t_\t_\t_\t_");
    }
    $self->write();
    $self->write();

    # read output
    my @parents = ();
    my @deprels = ();
    
    log_debug("$cnt to read", 1);
    my $line = $self->read();
    while ($line eq '') {
        $line = $self->read();
    }
    while ( $cnt > 0 ) {
        if ($line ne '') {
            $cnt--;
            my ($tokid, $form, $lemma, $cpostag, $postag, $feat, $parent, $deprel, $pparent, $pdeprel) = split(/\t/, $line);
            push @parents, $parent;
            push @deprels, $deprel;
            
        } else {
            log_fatal "Unexpected empty line";
        }
        log_debug("$cnt to read", 1);
        $line = $self->read();
    }

    return ( \@parents, \@deprels );
}

1;

__END__


=head1 NAME

Treex::Tools::Parser::LXParser

=head1 SYNOPSIS

  my $parser = Parser::LXParser->new();
  my ( $parent_indices, $afuns ) = $parser->parse( \@forms, \@lemmas, \@pos, \@subpos, \@features );

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
