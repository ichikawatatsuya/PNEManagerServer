<?php

namespace Deploy\HtmlBundle\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\Controller;


class DefaultController extends Controller
{
    
    public function indexAction()
    {
        return $this->redirect('/index.html');
    }
}
