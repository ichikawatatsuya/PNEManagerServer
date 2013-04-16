<?php

namespace PMS\ApiBundle\Lib;

use Symfony\Bundle\FrameworkBundle\Templating\EngineInterface;
use Symfony\Component\Routing\RouterInterface;
use Root\UserBundle\Entity\UserTemporary;

use PMS\ApiBundle\Entity\Sns;
use PMS\ApiBundle\Entity\Account;
use PMS\ApiBundle\Entity\SnsPasswords;

class Mailer
{

    protected $mailer;
    protected $templating;
    protected $parameters;

    public function __construct($mailer, EngineInterface $templating, array $parameters)
    {
        $this->mailer = $mailer;
        $this->templating = $templating;
        $this->parameters = $parameters;
    }

    public function sendInstallEmailMessage(Account $account, Sns $sns, SnsPasswords $passwords)
    {
        $template = $this->parameters['confirmation.template'];
        $rendered = $this->templating->render($template, array(
            'email' => $account->getEmail(),
            'domain' =>  $sns->getDomain(),
            'memberDefaultPassword' => $passwords->getMemberPassword(),
            'adminDefaultPassword' => $passwords->getAdminPassword(),
            'isPCallEdition' => !!strpos($sns->getOptions(), 'renrakumou'),
        ));

        $this->sendEmailMessage($rendered, $this->parameters['from_email']['confirmation'], $account->getEmail());
    }

    protected function sendEmailMessage($renderedTemplate, $fromEmail, $toEmail)
    {
        // Render the email, use the first line as the subject, and the rest as the body
        $renderedLines = explode("\n", trim($renderedTemplate));
        $subject = $renderedLines[0];
        $body = implode("\n", array_slice($renderedLines, 1));

        $message = \Swift_Message::newInstance()
            ->setSubject($subject)
            ->setFrom($fromEmail)
            ->setTo($toEmail)
            ->setBody($body);

        $this->mailer->send($message);
    }

}
