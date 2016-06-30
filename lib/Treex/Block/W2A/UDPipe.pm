package Treex::Block::W2A::UDPipe;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
with 'Treex::Core::RememberArgs';

use Treex::Tool::UDPipe;

has tokenize => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);

has tag => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);

has parse => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);

has known_models => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {{
        grc_proiel => 'data/models/udpipe/ancient-greek-proiel-ud-1.2-160523.udpipe',
        grc => 'data/models/udpipe/ancient-greek-ud-1.2-160523.udpipe',
        ar => 'data/models/udpipe/arabic-ud-1.2-160523.udpipe',
        eu => 'data/models/udpipe/basque-ud-1.2-160523.udpipe',
        bg => 'data/models/udpipe/bulgarian-ud-1.2-160523.udpipe',
        hr => 'data/models/udpipe/croatian-ud-1.2-160523.udpipe',
        cs => 'data/models/udpipe/czech-ud-1.2-160523.udpipe',
        da => 'data/models/udpipe/danish-ud-1.2-160523.udpipe',
        nl => 'data/models/udpipe/dutch-ud-1.2-160523.udpipe',
        en => 'data/models/udpipe/english-ud-1.2-160523.udpipe',
        et => 'data/models/udpipe/estonian-ud-1.2-160523.udpipe',
        fi => 'data/models/udpipe/finnish-ftb-ud-1.2-160523.udpipe',
        fi_ftb => 'data/models/udpipe/finnish-ud-1.2-160523.udpipe',
        fr => 'data/models/udpipe/french-ud-1.2-160523.udpipe',
        got => 'data/models/udpipe/gothic-ud-1.2-160523.udpipe',
        de => 'data/models/udpipe/german-ud-1.2-160523.udpipe',
        el => 'data/models/udpipe/greek-ud-1.2-160523.udpipe',
        he => 'data/models/udpipe/hebrew-ud-1.2-160523.udpipe',
        hi => 'data/models/udpipe/hindi-ud-1.2-160523.udpipe',
        hu => 'data/models/udpipe/hungarian-ud-1.2-160523.udpipe',
        id => 'data/models/udpipe/indonesian-ud-1.2-160523.udpipe',
        ga => 'data/models/udpipe/irish-ud-1.2-160523.udpipe',
        it => 'data/models/udpipe/italian-ud-1.2-160523.udpipe',
        la_itt => 'data/models/udpipe/latin-itt-ud-1.2-160523.udpipe',
        la_proiel => 'data/models/udpipe/latin-proiel-ud-1.2-160523.udpipe',
        la => 'data/models/udpipe/latin-ud-1.2-160523.udpipe',
        no => 'data/models/udpipe/norwegian-ud-1.2-160523.udpipe',
        cu => 'data/models/udpipe/old-church-slavonic-ud-1.2-160523.udpipe',
        fa => 'data/models/udpipe/persian-ud-1.2-160523.udpipe',
        po => 'data/models/udpipe/polish-ud-1.2-160523.udpipe',
        ro => 'data/models/udpipe/romanian-ud-1.2-160523.udpipe',
        pt => 'data/models/udpipe/portuguese-ud-1.2-160523.udpipe',
        sl => 'data/models/udpipe/slovenian-ud-1.2-160523.udpipe',
        es => 'data/models/udpipe/spanish-ud-1.2-160523.udpipe',
        ta => 'data/models/udpipe/tamil-ud-1.2-160523.udpipe',
        sv => 'data/models/udpipe/swedish-ud-1.2-160523.udpipe',
    }},
);

has model => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_model'
);

has using_lang_model => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_using_lang_model'
);

# If W2A::UDPipe is called on zones with no a-trees (which is the case with tokenize=1),
# let's create the (empty) a-trees automatically.
has '+if_missing_tree' => (default=>'create');

has tool => ( is=>'rw', lazy_build=>1);

sub _build_tool {
    my ($self) = @_;
    if ($self->has_model) {
        $self->args->{model} = $self->model;
    }
    elsif ($self->has_using_lang_model) {
        $self->args->{model} = $self->known_models()->{$self->using_lang_model};
    }
    else {
        log_fatal('Model path (model=path/to/model) or language (using_lang_model=XX) must be set!');
    }
    return Treex::Tool::UDPipe->new($self->args);
}

sub process_atree {
    my ($self, $root) = @_;

    my ($tok, $tag, $par) =  ($self->tokenize, $self->tag, $self->parse);
    return $self->tool->tokenize_tag_parse_tree($root) if  $tok &&  $tag &&  $par;
    return $self->tool->tokenize_tag_tree($root)       if  $tok &&  $tag && !$par;
    return $self->tool->tokenize_tree($root)           if  $tok && !$tag && !$par;
    return $self->tool->tag_parse_tree($root)          if !$tok &&  $tag &&  $par;
    return $self->tool->tag_tree($root)                if !$tok &&  $tag && !$par;
    return $self->tool->parse_tree($root)              if !$tok && !$tag &&  $par;
    log_fatal "Combination 'tokenize=$tok tag=$tag parse=$par' is not allowed";
    return;
}

1;
